package Nessy::Daemon::EventGenerator;

use strict;
use warnings FATAL => 'all';

use Nessy::Daemon::StateMachine;
use JSON;

use Nessy::Properties qw(
    command_interface
    state_machine
);

sub new {
    my $class = shift;
    my %params = @_;

    return bless $class->_verify_params(\%params, qw(
        state_machine
    )), $class;
}


sub start {
    my ($self, $command_interface) = @_;
    $self->_trigger_event($Nessy::Daemon::StateMachine::e_start,
        $command_interface);
}

sub shutdown {
    my ($self, $command_interface) = @_;
    $self->_trigger_event($Nessy::Daemon::StateMachine::e_shutdown,
        $command_interface);
}

sub release {
    my ($self, $command_interface) = @_;
    $self->_trigger_event($Nessy::Daemon::StateMachine::e_release,
        $command_interface);
}


sub http_response_callback {
    my ($self, $command_interface, $body, $headers) = @_;

    $self->_log_http_error_response($body, $headers);

    my $status_code = $headers->{Status};

    my %params;
    if ($status_code == 201 || $status_code == 202) {
        $params{update_url} = $headers->{location};
    }

    my $event_class = $self->_get_event_class($status_code);
    $self->_trigger_event($event_class, $command_interface, %params);
}


sub _log_http_error_response {
    my ($self, $body, $headers) = @_;

    my $status_code = $headers->{Status};
    my $status_category = _status_category($status_code);

    if ($status_category == 5
            || ($status_category == 4 && $status_code != 409)) {
        $self->_log_http_response($body, $headers);
    }
}

my $_json_parser;
sub _json_parser {
    $_json_parser ||= JSON->new;
}

sub _log_http_response {
    my ($self, $body, $headers) = @_;

    my $status_code = $headers->{Status};
    $self->_log("Unexpected HTTP Response (%d) %s:  '%s'", $status_code,
        $self->_json_parser->encode($headers), $body || '');
}

sub _log {
    my $self = shift;
    my $template = shift;

    my $message = sprintf($template, @_);

    print STDERR $message, "\n";
}


my %_SPECIFIC_EVENT_CLASSES = (
    201 => $Nessy::Daemon::StateMachine::e_http_201,
    202 => $Nessy::Daemon::StateMachine::e_http_202,
    409 => $Nessy::Daemon::StateMachine::e_http_409,
);
my %_GENERIC_EVENT_CLASSES = (
    2 => $Nessy::Daemon::StateMachine::e_http_2xx,
    4 => $Nessy::Daemon::StateMachine::e_http_4xx,
    5 => $Nessy::Daemon::StateMachine::e_http_5xx,
);
sub _get_event_class {
    my ($self, $status_code) = @_;

    if (exists $_SPECIFIC_EVENT_CLASSES{$status_code}) {
        return $_SPECIFIC_EVENT_CLASSES{$status_code};
    } else {
        my $category = _status_category($status_code);
        return $_GENERIC_EVENT_CLASSES{$category};
    }
}

sub _status_category {
    my $status_code = shift;
    return substr($status_code, 0, 1);
}

sub timer_callback {
    my ($self, $command_interface) = @_;
    $self->_trigger_event($Nessy::Daemon::StateMachine::e_timer,
        $command_interface);
}


sub timeout_callback {
    my ($self, $command_interface) = @_;
    $self->_trigger_event($Nessy::Daemon::StateMachine::e_timeout,
        $command_interface);
}

sub _trigger_event {
    my $self = shift;
    my $event_class = shift;
    my $command_interface = shift;

    my $event = $event_class->new(command_interface => $command_interface, @_);
    $self->state_machine->handle_event($event);
}


1;
