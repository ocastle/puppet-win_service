
Puppet::Type.newtype(:win_service) do

  desc "Puppet type for the management of windows service installation"

  ensurable

  newparam(:name, :namevar => true) do
    desc "Service name"
  end

  newparam(:display_name)do
    desc "Name of service to display else same as Service name"
  end

  newproperty(:binary_path_name)do
    desc "Binary path to service executable"
  end

  validate do
    fail('binary_path_name is required when ensure is present') if self[:ensure] == :present and self[:binary_path_name].nil?
  end

  newproperty(:start_type)do
    desc "Defined start_type aka start mode for windows service"
  end

  newproperty(:service_start_name)do
    desc "User name that service runs as"
  end

  newparam(:password) do
    desc "Credential password for username passed into type"
  end

  newparam(:password_checksum_path) do
    desc "Directory path to password checksum file"
  end

  autorequire(:file) do
    self[:binary_path_name] if self[:binary_path_name] and Pathname.new(self[:binary_path_name]).absolute?
  end

end