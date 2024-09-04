# Notes

## Ideas

1. Call execute with the following operations:
   1. Become proposer: _grantRole(PROPOSER_ROLE, address(this))
   2. updateDelay to 0
   3. Upgrade to a new implementation and set the player to be the sweeper
   4. schedule the operations done before -> it will immediately be executable because the readyAtTimestamp will be set to the current timestamp
2. Now that the player is the sweeper, it can call sweepFunds() on the old implementation to get all the tokens