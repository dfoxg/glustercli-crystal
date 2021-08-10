require "json"

require "./process_metrics"

module GlusterCLI
  struct ProcessMetric
    include JSON::Serializable

    property cpu_percentage = 0.0,
      memory_percentage = 0.0,
      uptime_seconds : UInt64 = 0

    def initialize
    end
  end

  class LocalMetrics
    include JSON::Serializable

    property bricks = Hash(String, ProcessMetric).new,
      glusterd = ProcessMetric.new,
      shds = [] of ProcessMetric,
      log_dir_size_bytes : UInt64 = 0,
      node_uptime_seconds : UInt64 = 0

    def initialize
    end

    # :nodoc:
    def self.node_uptime
      # TODO: Handle Error
      ret, output, err = GlusterCLI.execute_cmd("uptime", ["-s"])

      t1 = Time.parse(output.strip, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
      t2 = Time.utc
      (t2 - t1).total_seconds.to_u64
    end

    # :nodoc:
    def self.dir_size(dir)
      # TODO: Handle Error
      ret, output, err = GlusterCLI.execute_cmd("du", ["-s", dir])

      output.strip.split[0].to_u64
    end

    # :nodoc:
    def self.brick_metrics(process)
      brick = ProcessMetric.new
      pick_next_arg = false
      brick_path = ""
      process.args.each do |arg|
        if pick_next_arg
          brick_path = arg
          brick.cpu_percentage = process.pcpu
          brick.memory_percentage = process.pmem
          brick.uptime_seconds = process.uptime
          break
        end
        pick_next_arg = true if arg == "--brick-name"
      end

      {brick_path => brick}
    end

    # :nodoc:
    def self.glusterd_metrics(process)
      gd = ProcessMetric.new
      gd.cpu_percentage = process.pcpu
      gd.memory_percentage = process.pmem
      gd.uptime_seconds = process.uptime

      gd
    end

    # :nodoc:
    def self.shd_metrics(process)
      shd = ProcessMetric.new
      shd.cpu_percentage = process.pcpu
      shd.memory_percentage = process.pmem
      shd.uptime_seconds = process.uptime

      shd
    end

    # :nodoc:
    def self.shd_process?(process)
      pick_next_arg = false
      proc_name = ""
      process.args.each do |arg|
        if pick_next_arg
          proc_name = arg
          break
        end

        pick_next_arg = true if arg == "--process-name"
      end

      proc_name == "glustershd"
    end

    # :nodoc:
    def self.collect
      procs = ProcessData.collect(["glusterd", "glusterfsd", "glusterfs"])
      local_metrics = LocalMetrics.new
      local_metrics.node_uptime_seconds = node_uptime
      # TODO: Handle custom log directory
      local_metrics.log_dir_size_bytes = dir_size("/var/log/glusterfs")

      procs.each do |p|
        if p.command == "glusterfsd"
          local_metrics.bricks.merge!(brick_metrics(p))
        elsif p.command == "glusterd"
          local_metrics.glusterd = glusterd_metrics(p)
        elsif p.command == "glusterfs"
          if shd_process?(p)
            local_metrics.shds << shd_metrics(p)
          end
        end
      end

      local_metrics
    end
  end
end
