require 'gherkin/parser'
require 'gherkin/pickles/compiler'
require 'stepdown/scenario'

module Stepdown
  class Analyzer
    def initialize(steps_dir, feature_dir, reporter)
      @feature_dir = feature_dir
      @steps_dir = steps_dir
      @reporter = reporter
    end

    def analyze
      scenarios = collect_scenarios

      stats = Statistics.new(scenarios, instance.step_collection)
      stats.generate

      reporter = reporter(@reporter, stats)
      reporter.output_overview

      Stepdown::YamlWriter.write(stats)
      Stepdown::FlotGraph.create_graph
    end

    def collect_scenarios
      puts "Parsing feature files..." unless Stepdown.quiet
      process_feature_files(feature_files)
    end

    def process_feature_files(feature_files)
      scenarios = []
      parser = Gherkin::Parser.new
      feature_files.each do |feature_file|
        gherkin_document = parser.parse(File.read(feature_file))
        pickles = Gherkin::Pickles::Compiler.new.compile(gherkin_document, feature_file)
        scenarios << pickles.map{ |pickle| scenario_from_pickle(pickle) }
      end
      scenarios.flatten!
    end

    def reporter(type, stats)
      case type
        when "html"
          Stepdown::HTMLReporter.new(stats)
        when "text"
          Stepdown::TextReporter.new(stats)
        when "quiet"
          Stepdown::Reporter.new(stats)
      end
    end

    def instance
      @instance ||= begin
        new_inst = Stepdown::StepInstance.new

        Dir.glob(step_files).each do |file_name|
          new_inst.instance_eval File.read(file_name)
        end
        new_inst
      end
    end

    private
    def feature_files
      return @feature_files if @feature_files
      @feature_files = Dir.glob(@feature_dir + '/**/*.feature')
    end

    def step_files
      return @step_files if @step_files
      @step_files = Dir.glob(@steps_dir + '/**/*.rb')
    end

    def scenario_from_pickle(pickle)
      scenario = Scenario.new(pickle[:name])
      pickle[:steps].each do |step|
        matched_step = instance.line_matches(step[:text])
        scenario.add_step(matched_step) if matched_step
      end
      scenario
    end
  end
end
