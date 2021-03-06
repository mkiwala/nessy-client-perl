package StateMachine::Factory::EventState;

use strict;
use warnings FATAL => 'all';

use Sub::Install;
use Sub::Name;


sub _define_eventstate {
    my($class, $event_name, @property_list) = @_;

    my $event_class = join('::', $class, $event_name);
    {   no strict 'refs';
        if (scalar %{ $event_class . '::' }) {
            Carp::croak("$class already exists");
        }
        my $isa = join('::', $event_class, 'ISA');
        my $base_class = $class->_base_class;
        @$isa = ($base_class);
    }

    $event_class->_install_properties(@property_list);

    return $event_class;
}

package StateMachine::Factory::EventStateBase;

sub new {
    my $class = shift;
    my %props = @_;

    my $self = bless {}, $class;
    foreach my $prop ($class->_property_names) {
        if (!exists $props{$prop}) {
            Carp::confess("property '$prop' not specified for event");
        }
        $self->{$prop} = $props{$prop};
    }
    return $self;
}

sub _install_properties {
    my $class = shift;
    my @property_names = @_;

    Sub::Install::install_sub({
        code => sub {
            return @property_names;
        },
        into => $class,
        as => '_property_names',
    });

    for my $property_name (@property_names) {
        Sub::Install::install_sub({
            code => sub {
                my $self = shift;
                return $self->{$property_name};
            },
            into => $class,
            as => $property_name,
        });
    }
}

package StateMachine::Factory::Event;
BEGIN { our @ISA = qw(StateMachine::Factory::EventState) }
sub _base_class { 'StateMachine::Factory::EventBase' }
sub define_event {
    my $class = shift;
    $class->_define_eventstate(@_);
}

package StateMachine::Factory::EventBase;
BEGIN { our @ISA = qw(StateMachine::Factory::EventStateBase) }

package StateMachine::Factory::State;
BEGIN { our @ISA = qw(StateMachine::Factory::EventState) }
sub _base_class { 'StateMachine::Factory::StateBase' }
sub define_state {
    my $class = shift;
    $class->_define_eventstate(@_);
}

package StateMachine::Factory::StateBase;
BEGIN { our @ISA = qw(StateMachine::Factory::EventStateBase) }

sub lookup_key {
    my($self, $event) = @_;

    $self = ref($self) || $self;
    $event = ref($event) || $event;
    return join(':', $self, $event);
}


1;
