require 'mqtt'
require 'json'

class CommandDevice
  attr_reader :current_command, :command_id, :execution_id
  attr_accessor :status

  def initialize
    @mqtt_config = {
      host: "**************-ats.iot.ap-northeast-1.amazonaws.com",
      port: 8883,
      ssl: true,
      cert_file: "e8adb565/device.pem.crt",
      key_file: "e8adb565/private.pem.key",
      ca_file: "e8adb565/AmazonRootCA1.pem"
    }
    @thingName = "e8adb565"
    
    @command_base = "$aws/commands/things/#{@thingName}/executions"
    
    @topics = [
      @command_base + "/+/request/json",
      @command_base + "/+/response/accepted/json",
      @command_base + "/+/response/rejected/json",
      "$aws/events/commandExecution/+/+"
    ]
    
    @status = "IDLE"
    @current_command = nil
    @command_id = nil
  end

  def connect
    @client = MQTT::Client.connect(**@mqtt_config)
  end

  def subscribe
    Thread.new do 
      @client.get(@topics) do |topic, message|
        puts "\n#{topic}"
        puts JSON.pretty_generate(JSON.parse(message))
        
        if topic.include?("/request/")
          topic_parts = topic.split('/')
          execution_id = topic_parts[5]
          
          @current_command = {
            execution_id: execution_id,
            payload: JSON.parse(message, symbolize_names: true),
            response_topic: "$aws/commands/things/#{@thingName}/executions/#{execution_id}/response/json"
          }
          @execution_id = execution_id
        end
      end
    end
  end

  def progress(message_text = "Processing...")
    return puts "No active command" unless @current_command
    
    @status = "IN_PROGRESS"
    
    message = {
      status: "IN_PROGRESS",
      statusReason: {
        reasonCode: "200",
        reasonDescription: message_text
      },
      timestamp: Time.now.to_i
    }
    topic = @current_command[:response_topic]
    log_publish(topic, message)
    @client.publish(topic, message.to_json)
    puts "Progress: #{message_text}"
  end

  def complete(result = "completed")
    finish_command("SUCCEEDED", "200", result, { "message" => { "s" => result } }, "Command completed successfully")
  end

  def fail(error_message = "Command failed")
    finish_command("FAILED", "500", error_message, { "error" => { "s" => error_message } }, "Command failed: #{error_message}")
  end

  def reject(error_message = "Invalid or incompatible request")
    finish_command("REJECTED", "400", error_message, { "rejected_reason" => { "s" => error_message } }, "Command rejected: #{error_message}")
  end

  def info
    puts "\nStatus: #{@status}"
    if @current_command
      puts "ID: #{@current_command[:execution_id]}"
      puts "Payload: #{@current_command[:payload]}"
    else
      puts "No active command"
    end
  end

  def help
    puts "\nBasic methods:"

    puts "  device.progress                  # Report progress (default: 'Processing...')"
    puts "  device.progress('50% done')      # Report progress with custom message"
    puts "  device.complete                  # Complete successfully (default: 'completed')"
    puts "  device.complete('success')       # Complete with custom message"
    puts "  device.fail                      # Report failure (default: 'Command failed')"
    puts "  device.fail('custom error')      # Report failure with custom message"
    puts "  device.reject                    # Reject invalid request (default message)"
    puts "  device.reject('invalid format')  # Reject with custom message"

    puts "\nUtility methods:"
    puts "  device.info                      # Show current status"
    puts "  device.help                      # Show this help"
  end

  private

  def log_publish(topic, message)
    puts "\n→ #{topic}"
    puts JSON.pretty_generate(message)
  end

  def finish_command(status, reason_code, reason_desc, result, success_message)
    return puts "No active command" unless @current_command
    
    message = {
      status: status,
      result: result,
      timestamp: Time.now.to_i
    }
    
    if reason_code && reason_desc
      message[:statusReason] = {
        reasonCode: reason_code,
        reasonDescription: reason_desc
      }
    end
    
    topic = @current_command[:response_topic]
    log_publish(topic, message)
    @client.publish(topic, message.to_json)
    @status = status
    puts success_message
    reset_command
  end

  def reset_command
    @current_command = nil
    @execution_id = nil
    @status = "IDLE"
  end


end

# Helper for irb - usage: device = start_device
def start_device
  device = CommandDevice.new
  device.connect
  device.subscribe
  puts "\nDevice ready! Try: device.help"
  device
end

