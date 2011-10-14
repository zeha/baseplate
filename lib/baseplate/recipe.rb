require 'baseplate/support'
require 'tempfile'
module Baseplate
  class Recipe
    attr_accessor :opts

    def self.run(filename, opts)
      r = new
      r.opts.merge!(opts)
      r.instance_eval(File.read(filename), filename)
    end

    def initialize
      @opts = {}
    end

    def recipe
      yield
    end

    def setup_storage(&script)
      config = StorageConfig.evaluate(&script)

      tpl = Tempfile.new('setupstorage')
      tpl.write config
      tpl.close
      logdir = tpl.path + '.d'
      FileUtils.mkdir logdir

      path = '/usr/lib/fai:' + ENV['PATH']
      cmd = "PATH=#{path} HOME=#{logdir} LOGDIR=#{logdir} disklist=$(/usr/lib/fai/disk-info | sort) setup-storage -X -f #{tpl.path}"
      puts "* Execute: #{cmd}"
      if !@opts[:dryrun]
        p = IO.popen(cmd)
        out = p.readlines
        p.close

        if $?.exitstatus != 0
          raise "fai-setup-storage failed with exitstatus #{$?.exitstatus}. Output:\n#{out}"
        end
      else
        puts "  Config:"
        puts config
        puts "EOF"
      end

    ensure
      tpl.unlink unless tpl.nil?
      FileUtils.rm_r logdir unless logdir.nil?
    end

    def install_debian(&script)
      c = Debootstrap.evaluate(&script)
      c.run @opts
    end

    def reboot
      puts "Will reboot in 30 seconds..."
      sleep 30
      if !@opts[:dryrun]
        puts "Reboot..."
        Kernel.exec "reboot"
      else
        puts "Reboot (dry-run)."
        Process.exit!
      end
      # never get here
    end
  end

  class StorageConfig
    def self.evaluate(&script)
      c = new
      c.instance_eval(&script)
      c.config << ''
      c.config.join("\n")
    end

    attr_reader :config

    def initialize
      @config = []
    end

    def disk(name)
      @config << 'disk_config %s' % name.to_s
    end

    def primary(mountpoint, fstype, size, options = nil)
      if fstype.to_s == "swap"
        options ||= "sw"
      else
        options ||= "rw"
      end
      @config << 'primary %s %s %s %s' % [mountpoint, size, fstype, options]
    end
  end

  class Debootstrap
    def self.evaluate(&script)
      c = new
      c.instance_eval(&script)
      c
    end

    def initialize
      @opts = {}
      @hostname = `hostname -f`.chomp
      @release = :stable
      @vendor = :debian
      @packages = []
      @mirror = nil
      @root_device = nil
    end

    def mirror(line)
      @mirror = line
    end

    def package(name)
      @packages << name
    end

    def hostname(name)
      @hostname = name
    end

    def release(name)
      @release = name
    end

    def root_device(name)
      @root_device = name
    end

    # :nodoc:
    def run(opts)
      packagelist = Tempfile.new('packages')
      packagelist.write File.read('/etc/debootstrap/packages') unless opts[:dryrun] == true
      packagelist.write @packages.join(' ')
      packagelist.close

      # TODO - use --nopassword to avoid hanging process, available
      # with grml-debootstrap >= 0.48
      cmd = ['grml-debootstrap', '--force', '--hostname', @hostname, '--target', @root_device, '-v', '--packages', packagelist.path]
      if @mirror.nil? and @vendor == :ubuntu
        @mirror = 'http://archive.ubuntu.com/ubuntu/'
      end
      if @mirror
        cmd << '--mirror'
        cmd << @mirror
      end
      cmd << '--release'
      cmd << @release.to_s

      cmd = cmd.join(' ')
      puts "* Execute: #{cmd}"
      if !opts[:dryrun]
        p = IO.popen(cmd)
        out = p.readlines
        p.close
        if $?.exitstatus != 0
          raise "grml-debootstrap failed with exitstatus #{$?.exitstatus}. Output:\n#{out}"
        end
      end

    end
  end
end
