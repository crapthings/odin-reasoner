package reasoner

import "core:testing"

@(test)
test_smoke :: proc(t: ^testing.T) {
	testing.expect_value(t, VERSION, "0.0.0-dev")
}
