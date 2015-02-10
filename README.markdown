# win_service

Custom Type Provider for the creation/configuration of Windows Services. Currently this determins services installed to a Windows Host using the ruby gem 'win32-service'.
All updates to service configurations are facilitated with the sc.exe within Windows SCM.

The module is avialable from: https://forge.puppetlabs.com/ocastle/win_service

## Pre-requisites

- Windows
- Puppet installed via the Windows Installer
- 'win32-service' ruby gem

## Example Usage

```puppet

#Sample usage with minimum values given.

      win_service { 'defragsvc':
        ensure             => 'present',
        display_name       => 'Disk Defragmeter',
        binary_path_name   => 'C:\Windows\system32\svchost.exe -k defragsvc',
        service_start_name => 'localSystem',
        start_type         => 'demand',
}

#Sample usage when using an account other than localsystem.

      win_service { 'defragsvc':
        ensure                 => 'present',
        display_name           => 'Disk Defragmenter',
        binary_path_name       => 'C:\Windows\system32\svchost.exe -k defragsvc',
        service_start_name     => 'Your-Account-Name',
        password               => 'password',
        start_type             => 'demand',
        password_checksum_path => 'Path\to\put\md5\checksum',
}

```