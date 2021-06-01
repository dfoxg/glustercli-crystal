module GlusterCLI
  def self.execute_cmd(cmd, args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    status = Process.run(cmd, args: args, output: stdout, error: stderr)
    if status.success?
      {status.exit_code, stdout.to_s, stderr.to_s}
    else
      {status.exit_code, stderr.to_s, stderr.to_s}
    end
  end

  def self.execute_gluster_cmd(args)
    execute_cmd(@@gluster_executable, args)
  end
end
