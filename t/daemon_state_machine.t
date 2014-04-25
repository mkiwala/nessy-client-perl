use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::MockObject;


use_ok('Nessy::Daemon::StateMachine');


subtest 'shortest_release_path' => sub {
    my $sm = $Nessy::Daemon::StateMachine::factory->produce_state_machine();
    ok($sm, 'state machine created');

    my $ci = _mock_command_interface();

    _execute_event($sm, 'e_start', command_interface => $ci);
    _execute_event($sm, 'e_activate', command_interface => $ci,
        timer_seconds => 15);
    _execute_event($sm, 'e_release', command_interface => $ci);
    _execute_event($sm, 'e_success', command_interface => $ci);

    _verify_calls($ci,
        'register_claim',
        'create_timer',
        'notify_lock_active',
        'delete_timer',
        'release_claim',
        'notify_lock_released',
    );
};


done_testing();


sub _execute_event {
    my $sm = shift;
    my $event_name = shift;

    no strict;
    my $event_class_name = 'Nessy::Daemon::StateMachine::' . $event_name;
    my $event_class = $$event_class_name;
    $sm->handle_event($event_class->new(@_));
    use strict;
}

sub _mock_command_interface {
    my $ci = Test::MockObject->new();
    $ci->set_true(
        'register_claim',
        'create_timer',
        'notify_lock_active',
        'delete_timer',
        'release_claim',
        'notify_lock_released',
    );

    return $ci;
}

sub _verify_calls {
    my $ci = shift;

    for (my $position = 0; $position < scalar(@_); $position++) {
        my $call = $ci->next_call;
        is($call, $_[$position], sprintf('expected call "%s"', $_[$position]));
    }
    my $call = $ci->next_call;
    ok(!defined($call), 'no extra calls found');
}
