package pf::services::manager::collectd;

=head1 NAME

pf::services::manager::collectd

=cut

=head1 DESCRIPTION

pf::services::manager::collectd
collectd daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths qw(
    $install_dir
    $conf_dir
    $log_dir
);
use pf::util;
use pf::config qw(
    %Config
    $OS
    $management_network
);
use Moo;
use Sys::Hostname;

extends 'pf::services::manager';

has '+name'     => ( default => sub {'collectd'} );
has '+optional' => ( default => sub {1} );

sub _cmdLine {
    my $self = shift;
    $self->executable . " -P " . $self->pidFile . " -f -C $install_dir/var/conf/collectd.conf";
}

sub generateConfig {
    generateCollectd();
    generateTypes();
}

sub generateCollectd {
    my %tags;
    $tags{'template'}    = "$conf_dir/monitoring/collectd.conf.$OS";
    $tags{'install_dir'} = "$install_dir";
    $tags{'log_dir'}     = "$log_dir";
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');
    $tags{'graphite_host'} = "$Config{'graphite'}{'graphite_host'}";
    $tags{'graphite_port'} = "$Config{'graphite'}{'graphite_port'}";
    $tags{'hostname'}      = hostname;
    $tags{'db_host'}       = "$Config{'database'}{'host'}";
    $tags{'db_username'}   = "$Config{'database'}{'user'}";
    $tags{'db_password'}   = "$Config{'database'}{'pass'}";
    $tags{'db_database'}   = "$Config{'database'}{'db'}";
    $tags{'httpd_portal_modstatus_port'} = "$Config{'ports'}{'httpd_portal_modstatus'}";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/collectd.conf" );
}

sub generateTypes {
    my %tags;
    $tags{'template'}    = "$conf_dir/monitoring/types.db";
    $tags{'install_dir'} = "$install_dir";

    parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/types.db" );
}

1;
