#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'

class Project
  attr_reader :name

  NODE_TOTAL = Integer(ENV.fetch('CIRCLE_NODE_TOTAL', 1))
  NODE_INDEX = Integer(ENV.fetch('CIRCLE_NODE_INDEX', 0))

  ROOT          = Pathname.pwd.freeze
  VENDOR_BUNDLE = ROOT.join('vendor', 'bundle').freeze

  BUNDLER_JOBS    = 4
  BUNDLER_RETRIES = 3

  DEFAULT_MODE = 'test'.freeze

  def initialize(name)
    @name = name
  end

  ALL = %w[api backend core frontend sample].map(&method(:new)).freeze

  # Install subproject
  #
  # @raise [RuntimeError]
  #   in case of failure
  #
  # @return [self]
  #   otherwise
  def self.install
    bundle_check || bundle_install || fail('Cannot finish gem installation')
  end

  # Check if current bundle is already usable
  #
  # @return [Boolean]
  def self.bundle_check
    system(*%W[bundle check --path=#{VENDOR_BUNDLE}])
  end
  private_class_method :bundle_check

  # Install the current bundle
  #
  # @return [Boolean]
  #   the success of the installation
  def self.bundle_install
    system(*%W[
      bundle
      install
      --path=#{VENDOR_BUNDLE}
      --jobs=#{BUNDLER_JOBS}
      --retry=#{BUNDLER_RETRIES}
    ])
  end
  private_class_method :bundle_check

  # Test subproject for passing its tests
  #
  # @return [Boolean]
  #   the success of the build
  def pass?
    chdir do
      run_tests
    end
  end

  # Execute tests on subprojects
  #
  # @return [Boolean]
  #   the success of ALL subprojects
  def self.test
    projects = current_projects
    suffix   = "#{projects.length} projects(s) on node #{NODE_INDEX.succ} / #{NODE_TOTAL}"

    log("Running #{suffix}")
    projects.each do |project|
      log("- #{project.name}")
    end

    builds = projects.map do |project|
      log("Building: #{project.name}")
      project.pass?
    end
    log("Finished running #{suffix}")

    projects.zip(builds).each do |project, build|
      log("- #{project.name} #{build ? 'SUCCESS' : 'FAILURE'}")
    end

    builds.all?
  end
  private_class_method :test

  # Return the projects active on current node
  #
  # @return [Array<Project>]
  def self.current_projects
    NODE_INDEX.step(ALL.length - 1, NODE_TOTAL).map(&ALL.method(:fetch))
  end
  private_class_method :current_projects

  # Log a progress message to stderr
  #
  # @param [String] message
  #
  # @return [void]
  def self.log(message)
    $stderr.puts(message)
  end
  private_class_method :log

  # Process CLI arguments
  #
  # @param [Array<String>] arguments
  #
  # @return [Boolean]
  #   the success of the CLI run
  def self.run_cli(arguments)
    fail ArgumentError if arguments.length > 1
    mode = arguments.fetch(0, DEFAULT_MODE)

    case mode
    when 'install'
      install
      true
    when 'test'
      test
    else
      fail "Unknown mode: #{mode.inspect}"
    end
  end

  private

  # Run tests for subproject
  #
  # @return [Boolean]
  #   the success of the tests
  def run_tests
    @success = true
    run_test_cmd(%w[bundle exec rspec] + rspec_arguments)
    if name == "backend"
      run_test_cmd(%w[bundle exec teaspoon] + teaspoon_arguments)
    end
    @success
  end

  def run_test_cmd(args)
    puts "Run: #{args.join(' ')}"
    result = system(*args)
    puts(result ? "Success" : "Failed")
    @success &&= result
  end

  def teaspoon_arguments
    if report_dir
      %W[--format documentation,junit>#{report_dir}/rspec/#{name}_js.xml]
    else
      %w[--format documentation]
    end
  end

  def rspec_arguments
    args = []
    args += %w[--format documentation --profile 10]
    if report_dir
      args += %W[-r rspec_junit_formatter --format RspecJunitFormatter -o #{report_dir}/rspec/#{name}.xml]
    end
    args
  end

  def report_dir
    ENV['CIRCLE_TEST_REPORTS']
  end

  # Change to subproject directory and execute block
  #
  # @return [void]
  def chdir(&block)
    Dir.chdir(ROOT.join(name), &block)
  end
end # Project

exit Project.run_cli(ARGV)
