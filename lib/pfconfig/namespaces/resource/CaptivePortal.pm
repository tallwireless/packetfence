package pfconfig::namespaces::resource::CaptivePortal;

=head1 NAME

pfconfig::namespaces::resource::CaptivePortal

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::CaptivePortal

=cut

use strict;
use warnings;
use pf::file_paths qw($install_dir);
use POSIX;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{config} = $self->{cache}->get_cache('config::Pf');
}

sub build {
    my ($self) = @_;
    my %Config = %{ $self->{config} };

    # CAPTIVE-PORTAL RELATED
    # Captive Portal constants
    my %CAPTIVE_PORTAL = (
        "NET_DETECT_INITIAL_DELAY"         => floor( $Config{'fencing'}{'redirtimer'} / 4 ),
        "NET_DETECT_RETRY_DELAY"           => 2,
        "NET_DETECT_PENDING_INITIAL_DELAY" => 2 * 60,
        "NET_DETECT_PENDING_RETRY_DELAY"   => 30,
        "TEMPLATE_DIR"                     => "$install_dir/html/captive-portal/templates",
    );

    # process pf.conf's parameter into an IP => 1 hash
    %{ $CAPTIVE_PORTAL{'loadbalancers_ip'} }
        = map { $_ => 1 } split( /\s*,\s*/, $Config{'captive_portal'}{'loadbalancers_ip'} );
    return \%CAPTIVE_PORTAL;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

