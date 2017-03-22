package pfappserver::PacketFence::Controller::Admin;

=head1 NAME

pfappserver::PacketFence::Controller::Admin - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use namespace::autoclean;
use Moose;
use pfappserver::Form::SavedSearch;
use pf::admin_roles;
use pf::constants qw($TRUE $FALSE);
use List::MoreUtils qw(none);
use pf::pfcmd::checkup;
use pf::cluster;
use pf::authentication;
use pf::Authentication::constants qw($LOGIN_CHALLENGE);
use pf::db;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 METHODS

=head2 auto

Allow only authenticated users

=cut

sub auto :Private {
    my ($self, $c, @args) = @_;

    # Make sure the 'enforcements' session variable doesn't exist as it affects the Interface controller
    delete $c->session->{'enforcements'};

    my $action = $c->action->name;
    # login and logout actions have no checks
    if ($action eq 'login' || $action eq 'logout') {
        return 1;
    }

    # If user is not logged into the admin for proxy realm then send him to the login page
    unless ($c->user_allowed_in_admin()) {
        $c->stash->{'template'} = 'admin/login.tt';
        unless ($action eq 'index') {
            $c->stash->{status_msg} = $c->loc("Your session has expired.");
            $c->stash->{'redirect_action'} = $c->uri_for($c->action, @args);
        }
        $c->delete_session();
        $c->detach();
        return 0;
    }

    # If there is currently a challenge go to the challenge page
    if ($c->session->{user_challenge}) {
        $c->stash->{'template'} = 'admin/challenge.tt';
        $c->detach('challenge');
        return 0;
    }
    $c->stash->{readonly_mode} = db_check_readonly();

    return 1;
}

=head2 begin

Set the default view to pfappserver::View::Admin.

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'Admin';
}

=head2 login

Perform authentication using Catalyst Authentication plugin.

Upon successful authentication, redirect the user to the status page.

=cut

sub login :Local :Args(0) {
    my ( $self, $c ) = @_;
    my $req = $c->req;
    if (exists($req->params->{'username'}) && exists($req->params->{'password'})) {
        $c->stash->{current_view} = 'JSON';
        eval {
            if ($c->authenticate( { username => $req->params->{'username'}, password => $req->params->{'password'} } )) {
                my $user = $c->user;
                my $roles = [$user->roles];
                if (admin_can_do_any_in_group($roles, 'LOGIN_GROUP')) {
                    my $challenge = $user->_challenge;

                    # Save the roles to the session
                    $c->session->{user_roles} = $roles;
                    $c->session->{user_challenge} = $challenge;

                    # Save the updated roles data
                    $c->persist_user();

                    # Don't send a standard 302 redirect code; return the redirection URL in the JSON payload
                    # and perform the redirection on the client side
                    $c->response->status(HTTP_ACCEPTED);
                    if ($challenge) {
                        $c->stash->{success} = $c->uri_for($self->action_for('challenge'))->as_string;
                    } elsif ($req->params->{'redirect_url'}) {
                        $c->stash->{success} = $req->params->{'redirect_url'};
                    } else {
                        $c->stash->{success} = $c->uri_for($self->action_for('index'))->as_string;
                    }
                } else {
                    $c->response->status(HTTP_UNAUTHORIZED);
                    $c->stash->{status_msg} = $c->loc("You don't have the rights to perform this action.");
                    if (@$roles && none {$_ eq 'NONE'}) {
                        $c->log->error( "One of the following roles are not defined properly " . join(",", map { "'$_'" } @$roles));
                    }
                }
            } else {
                $c->response->status(HTTP_UNAUTHORIZED);
                $c->stash->{status_msg} = $c->loc("Wrong username or password.");
            }
        };
        if ($@) {
            $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
            $c->stash->{status_msg} = $c->loc("Unexpected error. See server-side logs for details.");
        }
    } elsif ($c->user_in_realm( 'admin' )) {
        $c->response->redirect($c->uri_for($self->action_for('index')));
        $c->detach();
    } elsif ($req->params->{'redirect_action'}) {
        $c->stash->{redirect_action} = $req->params->{'redirect_action'};
    }
}


=head2 challenge

=cut

sub challenge :Local :Args(0) {
    my ($self, $c) = @_;
    my $req = $c->req;
    my $user_challenge = $c->session->{user_challenge};
    unless (defined $user_challenge) {
        $c->response->redirect($c->uri_for($self->action_for('index')));
        $c->detach();
    }

    $c->stash({
        challenge_message => ($user_challenge->{message} // "Admin Login Challenge")
    });

    if (exists($req->params->{'challenge'})) {
        my $source = getAuthenticationSource($user_challenge->{id});
        my ($results, $message) = $source->challenge($c->user->id, $req->params->{'challenge'}, $user_challenge);
        $c->log->info("results : $results");
        if ($results == $FALSE) {
            $c->stash->{status_msg} = $c->loc("Invalid challenge.");
            $c->detach;
        }
        if ($results == $LOGIN_CHALLENGE) {
            $c->stash->{status_msg} = $c->loc("Another challenge.");
            $c->session->{user_challenge} = $message;
            $c->detach;
        }
        #If we are here then it was successful
        delete $c->session->{user_challenge};
        if ($req->params->{'redirect_action'}) {
            $c->response->redirect($req->params->{'redirect_action'});
        }
        else {
            $c->response->redirect($c->uri_for($self->action_for('index')));
        }
        $c->detach();
    }
}

=head2 logout

=cut

sub logout :Local :Args(0) {
    my ( $self, $c ) = @_;

    $c->logout();
    $c->delete_session();
    $c->stash->{'template'} = 'admin/login.tt';
    $c->stash->{'status_msg'} = $c->loc("You have been logged out.");
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my @roles = $c->user->roles();
    my $action;
    if (admin_can_do_any(\@roles,qw(SERVICES REPORTS))) {
        $action = 'status';
    } elsif( admin_can_do_any(\@roles,qw(USERS_READ USERS_READ_SPONSORED))) {
        $action = 'users';
    } elsif( admin_can_do_any(\@roles,qw(NODES_READ))) {
        $action = 'nodes';
    } elsif( admin_can_do_any_in_group(\@roles, 'CONFIGURATION_GROUP_READ' ) ) {
        $action = 'configuration';
    } else {
        $action = 'logout';
        $c->log->error("A role action is not properly defined");
    }
    $c->response->redirect($c->uri_for($c->controller->action_for($action)));
}

=head2 object

Administrator controller dispatcher

=cut

sub object :Chained('/') :PathPart('admin') :CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->stash->{'pf_release'}       = $c->model('Admin')->pf_release();
    $c->stash->{'server_hostname'}  = $c->model('Admin')->server_hostname();
}

=head2 status

=cut

sub status :Chained('object') :PathPart('status') :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{cluster_enabled} = $cluster_enabled;
}

=head2 reports

=cut

sub reports :Chained('object') :PathPart('reports') :Args(0) :AdminRole('REPORTS') {
    my ( $self, $c ) = @_;

    $c->forward('Controller::Graph', 'reports');
}

=head2 auditing

=cut

sub auditing :Chained('object') :PathPart('auditing') :Args(0) :AdminRole('AUDITING_READ') {
    my ( $self, $c ) = @_;
}

=head2 auditing_radius_log

=cut

sub auditing_radius_log :Chained('object') :PathPart('auditing/radius_log') :Args(0) :AdminRole('AUDITING_READ') {
    my ( $self, $c ) = @_;
    my $id = $c->user->id;
    my ($status, $saved_searches) = $c->model("SavedSearch::RadiusLog")->read_all($id);
    (undef, my $roles) = $c->model('Config::Roles')->listFromDB();
    my $sg = pf::ConfigStore::SwitchGroup->new;

    my $switch_groups = [
    map {
        local $_ = $_;
            my $id = $_;
            {id => $id, members => [$sg->members($id, 'id')]}
         } @{$sg->readAllIds}];
    my $switches_list = pf::ConfigStore::Switch->new->readAll("Id");
    my @switches_filtered = grep { !defined $_->{group} && $_->{Id} !~ /^group(.*)/ && $_->{Id} !~ m/\// && $_->{Id} ne 'default' } @$switches_list;
    my $switches = [
    map {
        local $_ = $_;
        my $id = $_->{Id};
        {id => $id}
        } @switches_filtered];
    my $sources = getAllAuthenticationSources();
    my $profiles = pf::ConfigStore::Profile->new->readAll("Id");
    my $domains = pf::ConfigStore::Domain->new->readAll("Id");
    my $realms = pf::ConfigStore::Realm->new->readAll("Id");
    $c->stash({
        template => 'admin/auditing_radius_log.tt',
        saved_searches => $saved_searches,
        saved_search_form => $c->form("SavedSearch"),
        switch_groups => $switch_groups,
        switches => $switches,
        roles => $roles,
        sources => $sources,
        profiles => $profiles,
        domains => $domains,
        realms => $realms,
    });
}

=head2 auditing_option82

=cut

sub auditing_option82 :Chained('object') :PathPart('auditing/option82') :Args(0) :AdminRole('AUDITING_READ') {
    my ( $self, $c ) = @_;
    my $id = $c->user->id;
    my ($status, $saved_searches) = $c->model("SavedSearch::DHCPOption82")->read_all($id);
    my $sg = pf::ConfigStore::SwitchGroup->new;

    my $switch_groups = [
    map {
        local $_ = $_;
            my $id = $_;
            {id => $id, members => [$sg->members($id, 'id')]}
         } @{$sg->readAllIds}];
    my $switches_list = pf::ConfigStore::Switch->new->readAll("Id");
    my @switches_filtered = grep { !defined $_->{group} && $_->{Id} !~ /^group(.*)/ && $_->{Id} !~ m/\// && $_->{Id} ne 'default' } @$switches_list;
    my $switches = [
    map {
        local $_ = $_;
        my $id = $_->{Id};
        {id => $id}
        } @switches_filtered];

    $c->stash({
        saved_searches => $saved_searches,
        saved_search_form => $c->form("SavedSearch"),
        switch_groups => $switch_groups,
        switches => $switches,
    });
}

=head2 nodes

=cut

sub nodes :Chained('object') :PathPart('nodes') :Args(0) :AdminRole('NODES_READ') {
    my ( $self, $c ) = @_;
    my $sg = pf::ConfigStore::SwitchGroup->new;
 
    my $switch_groups = [
    map {
        local $_ = $_;
            my $id = $_;
            {id => $id, members => [$sg->members($id, 'id')]}
         } @{$sg->readAllIds}];

    my $id = $c->user->id;
    my ($status, $saved_searches) = $c->model("SavedSearch::Node")->read_all($id);
    (undef, my $roles) = $c->model('Config::Roles')->listFromDB();
    my $switches_list = pf::ConfigStore::Switch->new->readAll("Id");
    my @switches_filtered = grep { !defined $_->{group} && $_->{Id} !~ /^group(.*)/ && $_->{Id} ne 'default' } @$switches_list;
    my $switches = [
    map {
        local $_ = $_;
        my $id = $_->{Id};
        {id => $id} 
        } @switches_filtered];

    $c->stash(
        saved_searches => $saved_searches,
        saved_search_form => $c->form("SavedSearch"),
        roles => $roles,
        switch_groups => $switch_groups,
        switches => $switches,
    );
}

=head2 users

=cut

sub users :Chained('object') :PathPart('users') :Args(0) :AdminRoleAny('USERS_READ') :AdminRoleAny('USERS_READ_SPONSORED') {
    my ( $self, $c ) = @_;
    my $id = $c->user->id;
    my ($status, $saved_searches) = $c->model("SavedSearch::User")->read_all($id);
    $c->stash(
        saved_searches => $saved_searches,
        saved_search_form => $c->form("SavedSearch")
    );
}

=head2 configuration

=cut

sub configuration :Chained('object') :PathPart('configuration') :Args(0) {
    my ( $self, $c, $section ) = @_;

}

=head2 checkup

=cut

sub checkup :Chained('object') :PathPart('checkup') :Args(0) {
    my ( $self, $c ) = @_;
    my @problems = sanity_check();
    $c->stash->{items}->{problems} = \@problems;
    $c->stash->{current_view} = 'JSON';
}

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

__PACKAGE__->meta->make_immutable;

1;
