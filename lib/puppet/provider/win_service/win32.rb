require 'puppet'
require 'win32/service'
require 'digest/md5'
require 'win32/registry'
include Win32

Puppet::Type.type(:win_service).provide(:win32) do

  desc "win32 service provider for windows"

  confine :operatingsystem => [:windows]

  commands :sc => 'sc.exe'

  ## self.instances help methods ##
  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    get_services.collect do |int|
      service_properties = get_service_properties(int)
      new(service_properties)
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.get_services
    services = []
    Puppet.debug "Get array of service instances"
    Service.services do |service|
      services.push(service.service_name)
    end
    services
  end

  def self.get_service_properties(service_name)
    service_properties = {}

    begin
      Puppet.debug "Get #{service_name} service properties"
      output = Service.config_info(service_name) rescue nil
    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "#win_service tried to get_service_properties for #{service_name} and failed to return a non-zero"
    end

    service_properties[:ensure]             = output == nil ? :absent : :present
    service_properties[:name]               = service_name
    if output != nil
      service_properties[:display_name]       = output.display_name
      service_properties[:service_type]       = output.service_type
      #service_properties[:error_control]      = output.error_control
      #service_properties[:load_order_group]   = output.load_order_group
      #service_properties[:tag_id]             = output.tag_id
      #service_properties[:dependencies]       = output.dependencies
      service_properties[:binary_path_name]   = output.binary_path_name
      service_properties[:service_start_name] = output.service_start_name
      service_properties[:start_type]         = get_start_type(service_name, output.start_type)
    end
    Puppet.debug "Service properties:  #{service_properties.inspect}"
    service_properties
  end

  def self.key_exists?(path,key)
    reg_type = Win32::Registry::KEY_READ
    Win32::Registry::HKEY_LOCAL_MACHINE.open(path, reg_type) do |reg|
      begin
        regkey = reg[key]
        return true
      rescue
        return false
      end
    end
  end

  def self.delayed?(service_name)
    registry_path = "SYSTEM\\CurrentControlSet\\services\\#{service_name}"

    if key_exists?(registry_path, 'DelayedAutostart')
      Win32::Registry::HKEY_LOCAL_MACHINE.open(registry_path) do |reg|
        if reg['DelayedAutostart'] == 1
          return true
        else
          return false
        end
      end
    else
      return false
    end
  end

  def self.get_start_type(servicename, starttype_property)
    case starttype_property
    when 'auto start'
      if self.delayed?(servicename) == true
        return 'delayed-auto'
      else
        return 'auto'
      end
    when 'demand start'
      return 'demand'
    when 'disabled'
      return'disabled'
    end
  end

  #################################

  ### Additional Helper Methods ###
  def checksum_name
    return "#{resource[:name]}-#{resource[:service_start_name]}.md5"
  end

  def create_checksum(path)
    path = path.gsub('\\', '/')
    fullpath = "#{path}/#{checksum_name}"
    hash = convert_to_md5(resource[:password])
    Puppet.debug "Permissions for #{path} are #{File.stat(path).mode.to_s(8)[2..5]}"
    begin
      remove_legacyhash(fullpath)
      if File.exists?(fullpath)
        remove_file(fullpath)
      end
      File.open(fullpath, 'w') do |f|
        f.write(hash)
      end
    rescue Exception => e
      raise "Could not create checksum. The path was #{fullpath}. The exception was #{e.message}. The content was #{hash}."
    end
  end

  def checksum_difference?(path)
    if convert_to_md5(resource[:password]) != read_file(path)
      return true
    else
      return false
    end
  end

  def remove_legacyhash(path)
    legacy_hash = path.gsub(".md5", ".hash")
    Puppet.debug "Legacy hash => #{legacy_hash}"

    if File.exists?(legacy_hash)
      Puppet.debug "Legacy hash found"
      remove_file(legacy_hash)
    end
  end

  def get_permissions(path)
    if File.directory?(path)
      perm = File.stat(path).mode.to_s(8)[2..5]
    else
      perm = File.stat(path).mode.to_s(8)[3..5]
    end
    return perm
  end

  def read_file(path_to_file)
    Puppet.debug "Reading file => #{path_to_file}"
    if File.exists?(path_to_file)
      return File.open(path_to_file, 'r') { |file| file.read }
    else
      return nil
    end
  end

  def remove_file(filename)
    Puppet.debug "Removing File => #{filename}"
    File.delete(filename)
  end

  def convert_to_md5(string_to_hash)
    Digest::MD5.hexdigest(string_to_hash).chomp
  end

  def set_displayname(string)
    if resource[:display_name] == nil
      return resource[:name]
    else
      return resource[:display_name]
    end
  end

  def set_startmode(startvalue)
    case startvalue
    when 'auto', 'delayed-auto'
      mode = Service::AUTO_START
    when 'demand'
      mode = Service::DEMAND_START
    when 'system'
      mode = Service::SYSTEM_START
    when 'boot'
      mode = Service::BOOT_START
    when 'disabled'
      mode = Service::DISABLED
    end
    return mode
  end

  def key_exists?(path,key)
    reg_type = Win32::Registry::KEY_READ
    Win32::Registry::HKEY_LOCAL_MACHINE.open(path, reg_type) do |reg|
      begin
        regkey = reg[key]
        return true
      rescue
        return false
      end
    end
  end

  def write_regvalue(action, path, key, value)
    reg_type = Win32::Registry::KEY_ALL_ACCESS
    Win32::Registry::HKEY_LOCAL_MACHINE.open(path, reg_type) do |reg|
      case action
      when "create"
        reg.write(key, Win32::Registry::REG_DWORD, value)
      when "edit"
        reg[key] = value
      end
    end
  end

  def destroy_service
    Puppet.debug "Delete Service #{resource[:name]}"
    Service.delete(resource[:name])
  end

  def create_service
    if ((resource[:service_start_name] != nil) && (resource[:service_start_name] != "LocalSystem") && (resource[:service_start_name] != ""))
      Puppet.debug "sc create #{resource[:name]} DisplayName= #{set_displayname(resource[:display_name])} start= #{resource[:start_type]} binPath= #{resource[:binary_path_name]} obj= #{resource[:service_start_name]} password= ***"
      sc('create',
         resource[:name],
         "DisplayName=", "#{set_displayname(resource[:display_name])}",
         "start=", "#{resource[:start_type]}",
         "binPath=", "#{resource[:binary_path_name]}",
         "obj=", "#{resource[:service_start_name]}",
         "password=", "#{resource[:password]}")
    else
      Puppet.debug "sc create #{resource[:name]} DisplayName= #{set_displayname(resource[:display_name])} start= #{resource[:start_type]} binPath= #{resource[:binary_path_name]}"
      sc('create',
         resource[:name],
         "DisplayName=", "#{set_displayname(resource[:display_name])}",
         "start=", "#{resource[:start_type]}",
         "binPath=", "#{resource[:binary_path_name]}")
    end
  end

  def configure_service
    if ((resource[:service_start_name] != nil) && (resource[:service_start_name] != "LocalSystem") && (resource[:service_start_name] != ""))
      Puppet.debug "sc config #{resource[:name]} DisplayName= #{set_displayname(resource[:display_name])} start= #{resource[:start_type]} binPath= #{resource[:binary_path_name]} obj= #{resource[:service_start_name]} password= ***"
      sc('config',
         resource[:name],
         "DisplayName=", "#{set_displayname(resource[:display_name])}",
         "start=", "#{resource[:start_type]}",
         "binPath=", "#{resource[:binary_path_name]}",
         "obj=", "#{resource[:service_start_name]}",
         "password=", "#{resource[:password]}")
    else
      Puppet.debug "sc create #{resource[:name]} DisplayName= #{set_displayname(resource[:display_name])} start= #{resource[:start_type]} binPath= #{resource[:binary_path_name]}"
      sc('config',
         resource[:name],
         "DisplayName=", "#{set_displayname(resource[:display_name])}",
         "start=", "#{resource[:start_type]}",
         "binPath=", "#{resource[:binary_path_name]}")
    end
  end

  def set_service
    Puppet.debug "Flush: set_service #{@property_hash[:ensure]}"
    if @property_flush[:ensure] == :absent
      destroy_service
      return
    end
    if @property_hash[:ensure] == :present
      configure_service
      return
    end
    if @property_hash[:ensure] != :present
      create_service
      return
    end
  end

  def set_checksum
    Puppet.debug "Flush: set_checksum"
    if resource[:password_checksum_path] != nil
      if @property_flush[:ensure] == :absent
        remove_file("#{resource[:password_checksum_path]}/#{checksum_name}")
        return
      end
      if @property_hash[:ensure] == :present
        create_checksum("#{resource[:password_checksum_path]}")
        return
      end
      if ! @property_hash[:ensure] == :present
        create_checksum("#{resource[:password_checksum_path]}")
        return
      end
    end
  end
  #################################

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  ######## Getter Methods #########
  def binary_path_name
    @property_hash[:binary_path_name]
  end

  def start_type
    @property_hash[:start_type]
  end

  def service_start_name
    if resource[:password_checksum_path] != nil
      if checksum_difference?("#{resource[:password_checksum_path]}/#{checksum_name}") == true
        return "#{@property_hash[:service_start_name]}(out-of-sync)"
      end
    end

    return @property_hash[:service_start_name]
  end
  #################################

  ######## Setter Methods #########
  def binary_path_name=(value)
    @property_flush[:binary_path_name] = value
  end

  def start_type=(value)
    @property_flush[:start_type] = value
  end

  def service_start_name=(value)
    @property_flush[:service_start_name] = value
  end

  def flush
    set_service
    set_checksum

    # Collect the resources again once they've been changed (that way `puppet
    # resource` will show the correct values after changes have been made).
    Puppet.debug "Flush : service properties for #{resource[:name]}"
    @property_hash = self.class.get_service_properties(resource[:name])
  end
  #################################
end
