# tp_profile::apache
#
# @summary This tp profile manages apache with Tiny Puppet (tp)
#
# When you include this class the relevant tp::install define is declared
# which is expected to install apache package and manage its service.
# Via the resources_hash parameter is possible to pass hashes of tp::conf and
# tp::dir defines which can manage apache configuration files and
# whole dirs.
# All the parameters ending with the _hash suffix expect and Hash and are looked
# up on Hiera via the deep merge lookup option.
#
# @example Just include it to install apache
#   include tp_profile::apache
#
# @example Include via psick module classification (yaml)
#   psick::profiles::linux_classes:
#     apache: tp_profile::apache
#
# @example To use upstream repos instead of OS defaults (if tinydata available) as packages source:
#   tp_profile::apache::upstream_repo: true
#
# @example Manage extra configs via hiera (yaml) with templates based on custom options
#   tp_profile::apache::ensure: present
#   tp_profile::apache::resources:
#     tp::conf:
#       apache:
#         epp: profile/apache/apache.conf.epp
#       apache::dot.conf:
#         epp: profile/apache/dot.conf.epp
#         base_dir: conf
#     exec:
#       apache::setup:
#         command: '/usr/local/bin/apache_setup'
#         creates: '/opt/apache'
#   tp_profile::apache::options_hash:
#     key: value
#
# @example Enable default auto configuration, if configurations are available
#   for the underlying system and the given auto_conf value, they are
#   automatically added.
#   tp_profile::apache::auto_conf: true
#
# @param manage If to actually manage any resource in this profile or not.
# @param ensure If to install or remove apache. Valid values are present, absent, latest
#   or any version string, matching the expected apache package version.
# @param upstream_repo If to use apache upstream repos as source for packages
#   or rely on default packages from the underlying OS.
#
# @param install_hash An hash of valid params to pass to tp::install defines. Useful to
#   manage specific params that are not automatically defined.
# @param options_hash An open hash of options to use in the templates referenced
#   in the tp::conf entries of the $resources_hash.
# @param settings_hash An hash of tp settings to override default apache file
#   paths, package names, repo info and whatever tinydata that matches Tp::Settings data type:
#   https://github.com/example42/puppet-tp/blob/master/types/settings.pp.
#
# @param auto_conf If to enable automatic configuration of apache based on the
#   resources_auto_conf_hash and options_auto_conf_hash parameters, if present in
#   data/common/apache.yaml. You can both override them in your Hiera files
#   and merge them with your resources_hash and options_hash.
# @param resources_auto_conf_hash The default resources hash if auto_conf is true.
#   The final resources managed are the ones specified here and in $resources.
#   Check tp_profile::apache::resources_auto_conf_hash in
#   data/common/apache.yaml for the auto_conf defaults.
# @param options_auto_conf_hash The default options hash if auto_conf is set.
#   Check tp_profile::apache::options_auto_conf_hash in
#   data/common/apache.yaml for the auto_conf defaults.
#
# @param resources An hash of any resource, like tp::conf, tp::dir, exec or whatever
#   to declare for apache confiuration. Can also come from a third-party
#   component modules with dedicated apache resources.
#   tp::conf params: https://github.com/example42/puppet-tp/blob/master/manifests/conf.pp
#   tp::dir params: https://github.com/example42/puppet-tp/blob/master/manifests/dir.pp
#   any other Puppet resource type, with relevant params can be actually used
#   The Hiera lookup method used for this parameter is defined with the $resource_lookup_method
#   parameter.
# @param resource_lookup_method What lookup method to use for tp_profile::apache::resources
# @param resources_defaults An Hash of resources with their default params, to be merged with
#   $resources.
#
# @param auto_prereq If to automatically install eventual dependencies for apache.
#   Set to false if you have problems with duplicated resources, being sure that you
#   manage the prerequistes to install apache (other packages, repos or tp installs).
# @param no_noop Set noop metaparameter to false to all the resources of this class. If set,
#   the trlinkin/noop module is required.
#
class tp_profile::apache (
  Tp_Profile::Ensure $ensure                   = 'present',
  Boolean            $manage                   = true,
  Optional[Boolean]  $upstream_repo            = undef,

  Hash               $install_hash             = {},
  Hash               $options_hash             = {},
  Hash               $settings_hash            = {},

# This param is looked up in code according to $resources_lookup_method
#  Hash               $resources                = {},
  Hash               $resources_defaults       = {},
  Hash               $resources_lookup_method  = 'deep',

  Boolean            $auto_conf                = false,
  Hash               $resources_auto_conf_hash = {},
  Hash               $options_auto_conf_hash   = {},

  Boolean            $auto_prereq              = true,
  Boolean            $no_noop                  = false,
) {

  if $manage {
    if $no_noop {
      info('Forced no-noop mode in tp_profile::apache')
      noop(false)
    }
    $options_all = $auto_conf ? {
      true  => $options_auto_conf_hash + $options_hash,
      false => $options_hash,
    }
    
    $install_defaults = {
      ensure        => $ensure,
      options_hash  => $options_all,
      settings_hash => $settings_hash,
      auto_repo     => $auto_prereq,
      auto_prereq   => $auto_prereq,
      upstream_repo => $upstream_repo,
    }
    tp::install { 'apache':
      * => $install_defaults + $install_hash,
    }

    $file_ensure = $ensure ? {
      'absent' => 'absent',
      default  => 'present',
    }
    $dir_ensure = $ensure ? {
      'absent' => 'absent',
      default  => 'directory',
    }

    # Declaration of tp_profile::apache::resources
    $resources=lookup('tp_profile::apache::resources, Hash, $resources_lookup_method, {})
    $resources.each |String $resource_type, Hash $content| {
      $resources_all = $auto_conf ? {
        true  => pick($resources_auto_conf_hash[$resource_type], {}) + pick($resources[$resource_type], {}),
        false => pick($resources[$resource_type], {}),
      }
      $resources_all.each |String $resource_name, Hash $resource_params| {
        $resources_params_default = $resource_type ? {
          'tp::conf' = {
            ensure        => $file_ensure,
            options_hash  => $options_all,
            settings_hash => $settings_hash,
          },
          'tp::dir = {
            ensure        => $dir_ensure,
            settings_hash => $settings_hash,
          },
          'exec' = {
            path = $::path,
          },
          'file' = {
            ensure        => $file_ensure,
          },
          default = {},
        }
        $resource_params_all = deep_merge($resources_defaults[$resource_type], $resources_params_default, $resource_params)
        ensure_resource($resource_type,$resource_name,$resource_params_all)
      }
    }
  }
}
