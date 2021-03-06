package StateMachine::Factory;

use strict;
use warnings FATAL => 'all';

use Data::UUID;
use StateMachine::Factory::EventState;
use StateMachine::Factory::Transition;
use StateMachine::Definition;

my $_ID_GEN = new Data::UUID;


sub new {
    my $class = shift;

    return bless {
        _transitions => {},
        _initial_state_type => undef,
        _random_id => $_ID_GEN->create_b64,
        _is_concrete => 0
    }, $class;
}

sub define_state {
    my $self = shift;
    my $state_name = shift;

    $self->_verify_not_concrete;
    return StateMachine::Factory::State->define_state(
        $self->_uniquify_name($state_name), @_);
}

sub define_event {
    my $self = shift;
    my $event_name = shift;

    $self->_verify_not_concrete;
    return StateMachine::Factory::Event->define_event(
        $self->_uniquify_name($event_name), @_);
}

sub _uniquify_name {
    my $self = shift;
    my $original_name = shift;

    return sprintf("%s:%s", $self->{_random_id}, $original_name);
}

sub define_transitions {
    my $self = shift;

    foreach my $listref ( @_ ) {
        $self->define_transition(@$listref);
    }
}

sub _verify_not_concrete {
    my $self = shift;

    if ($self->{_is_concrete}) {
        Carp::croak("Cannot modify a " . ref($self)
            . " after producing a state machine");
    }
    return 1;
}


sub define_transition {
    my($self, $from, $event, $to, $action_list) = @_;

    $self->_verify_not_concrete;

    my $trans = StateMachine::Factory::Transition->new(from => $from,
        event => $event, to => $to, action_list => $action_list);
    my $lookup_key = $trans->lookup_key();

    my $transitions = $self->{_transitions};
    if ($transitions->{$lookup_key}) {
        Carp::croak("Tried to create a conflicting transition "
            . $trans->as_string
            . "\n    existing transition: "
            . $transitions->{$lookup_key}->as_string());
    }

    $transitions->{$lookup_key} = $trans;

    return $trans;
}

sub define_start_state {
    my $self = shift;
    if ($self->{_initial_state_type}) {
        Carp::croak("Initial state is already " . $self->{_initial_state_type});
    }

    my $initial_state_type = $self->define_state(@_);
    $self->{_initial_state_type} = $initial_state_type;
    return $initial_state_type;
}

sub produce_state_machine {
    my $self = shift;

    $self->{_is_concrete} = 1;

    unless ($self->{_initial_state_type}) {
        Carp::croak("define_start_state() was not called");
    }

    my $initial_state = $self->{_initial_state_type}->new(@_);
    my $transitions = $self->{_transitions};
    my $sm = StateMachine::Definition->new($initial_state, $transitions);
    return $sm;
}

1;
