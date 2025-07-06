# AWS IoT Device Management Commands Client

* A client for testing AWS IoT Device Management Commands functionality.
* Synchronizes command execution status with the cloud via MQTT messages.
* This implementation is a sample for processing a single command and cannot handle multiple commands simultaneously.

```
irb(main):003> device.help

Basic methods:
  device.progress                  # Report progress (default: 'Processing...')
  device.progress('50% done')      # Report progress with custom message
  device.complete                  # Complete successfully (default: 'completed')
  device.complete('success')       # Complete with custom message
  device.fail                      # Report failure (default: 'Command failed')
  device.fail('custom error')      # Report failure with custom message
  device.reject                    # Reject invalid request (default message)
  device.reject('invalid format')  # Reject with custom message

Utility methods:
  device.info                      # Show current status
  device.help                      # Show this help
```

## MQTT Topics
Command execution topics follow this format:
```
$aws/commands/things/{thingName}/executions/{executionId}/{type}/json
```

- `{executionId}`: Unique identifier for command execution
- `{type}`: request or response

### Subscribed Topics

The client subscribes to the following 4 topics:

- `$aws/commands/things/{thingName}/executions/+/request/json`: Command reception
- `$aws/commands/things/{thingName}/executions/+/response/accepted/json`: Response acceptance confirmation
- `$aws/commands/things/{thingName}/executions/+/response/rejected/json`: Response rejection details
- `$aws/events/commandExecution/+/+`: Command execution status changes

### Example of Received Command Message

```json
{
  "command": "app_upgrade",
  "option": "-all"
}
```

## Command Execution Operations

Install the required MQTT gem:

```bash
gem install mqtt
```

Specify the IoT Core endpoint and certificate paths in `commands.rb` before starting the client.

```ruby
host: "**************-ats.iot.ap-northeast-1.amazonaws.com"
cert_file: "path/to/certificate.pem.crt"
key_file: "path/to/private.pem.key"
ca_file: "path/to/AmazonRootCA1.pem"
```

Startup Instructions

Execute the following commands after starting `irb`:

```ruby
require_relative 'commands.rb'

# Initialize device
device = start_device

# Basic usage examples
# 1. When a command is received
device.progress("Starting...")    # Report progress (automatically transitions to IN_PROGRESS)
device.complete("Success")        # Report completion

# Or complete directly
device.complete("Processing complete")  # Possible without progress

# Command reception and response
device.progress("Processing...")  # Progress report
device.progress("50% done")       # Progress update
device.complete("success")        # Normal completion
device.fail("Error message")      # Error report
device.reject("Invalid request")  # Request rejection

# Check execution status
device.info          # Display current status
device.help          # Display help
```


## CloudWatch Logs Verification

Detailed logs of MQTT messages can be verified in CloudWatch Logs:
- Set log level in AWS IoT > Settings > Logs
- Check details in CloudWatch > Log groups

## Command Execution Status Verification with AWS CLI

### Available Commands

With AWS CLI v2.22 and later, the following commands are available:

```bash
# Get command execution details - can check status and statusReason during IN_PROGRESS
aws iot get-command-execution \
  --execution-id <execution-id> \
  --target-arn arn:aws:iot:<region>:<account-id>:thing/<thing-name> \
  --include-result

# List command executions
aws iot list-command-executions

# Get command details
aws iot get-command --command-id <command-id>

# List commands
aws iot list-commands
```

### Execution Status Verification Example

* The content of `result` can be verified in the console.
* `status` and `statusReason` can be verified using the above CLI or by subscribing to event topics.
  * This sample client also subscribes to event topics.

CLI

```bash
# Actual usage example
aws iot get-command-execution \
  --execution-id 7433bb2b-dba3-48f1-aec9-d0d0bf7fa684 \
  --target-arn arn:aws:iot:ap-northeast-1:<account-id>:thing/e8adb565 \
  --include-result
```


### Verifiable Information

- **status**: Command execution state (CREATED, IN_PROGRESS, SUCCEEDED, FAILED, TIMED_OUT)
- **statusReason**: Detailed status information (reasonCode, reasonDescription)
- **result**: Final execution result (DynamoDB format)
- **executionTimeoutSeconds**: Timeout duration
- **createdAt/lastUpdatedAt**: Creation/update timestamps


### Development Notes

- **TIMED_OUT + $NO_RESPONSE_FROM_DEVICE**: Device is not responding
- **InvalidRequest + "At least 1 command execution result is required"**: `result` field is empty
- **"Value cannot be a STRING"**: Sending string directly without specifying format. Correct format is `{"key": {"s": "value"}}`
