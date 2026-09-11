package app

const (
	ExitOK          = 0
	ExitGeneral     = 1
	ExitUsage       = 2
	ExitUnauth      = 3
	ExitForbidden   = 4
	ExitUnavailable = 5
	ExitRunFailed   = 6
	ExitWaitTimeout = 7
)

type CLIError struct {
	Code      string
	Message   string
	RequestID string
	Details   any
	ExitCode  int
}

func (e *CLIError) Error() string { return e.Message }

func exitForStatus(status int) int {
	switch status {
	case 401:
		return ExitUnauth
	case 403:
		return ExitForbidden
	case 408, 429:
		return ExitUnavailable
	default:
		if status >= 500 || status == 0 {
			return ExitUnavailable
		}
		return ExitGeneral
	}
}
