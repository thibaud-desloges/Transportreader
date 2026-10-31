import Foundation

var lease = RegionalSessionLease()
let first = lease.begin()
precondition(lease.accepts(first))
lease.end()
precondition(!lease.accepts(first))
let resumed = lease.begin()
precondition(resumed != first && lease.accepts(resumed))
// A late reply from the previous session is rejected while resume is active.
precondition(!lease.accepts(first))
lease.end()
precondition(!lease.accepts(resumed))
let third = lease.begin()
precondition(!lease.accepts(resumed) && lease.accepts(third))
print("RegionalSessionLease: cancellation, resume and stale-reply checks passed")
