### v0.4.0 (16/2/16)

- Added support for loading config from environment variables.

### v0.3.0 (11/2/16)

- Library is now a lot more forgiving on startup if config keys are missing.
  It just doesn't start things, rather than trying to and crashing.
- The "host" setting now defaults to the current hostname, and can be
  overridden using functions as well as hard coding a name.

### v0.2.0 (9/2/16)

- Expanded the library to include more than just a reporter.
- It's now an OTP application that will:
  - Automatically register the reporter with exometer
  - Optionally report system & vm metrics to datadog.
- Wrote a lot more documentation.

### v0.1 (7/2/16)

- Initial release of the library.
- Contains a working exometer reporter for datadog.
- Configured via the usual exometer config for reporters.
