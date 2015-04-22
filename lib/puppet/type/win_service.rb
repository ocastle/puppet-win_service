
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

  newproperty(:reset_period)do
    desc "Length of the period (in seconds) with no failurs after which the failure count should be reset to 0. Requires failure_actions attribute be provided"
    defaultto "0"
    validate do |value|
      unless value =~ /^\d+$/
        raise ArugmentError, 'win_service::reset_period invalid, must enter a time in milliseconds'
      end
    end
  end

  newproperty(:reboot_message)do
    desc "Message to broadcase when service fails."
  end

  newproperty(:command)do
    desc "Command line command to be run when the service fails."
  end


  newproperty(:failure_actions, :array_matching => :all)do
    desc "Specifies one to three failure actions and their delay times (in milliseconds). Valid actions are run, restart, reboot. Requires reset_period attribue be provided"
  end

  autorequire(:file) do
    self[:binary_path_name] if self[:binary_path_name] and Pathname.new(self[:binary_path_name]).absolute?
  end

end