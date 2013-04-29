#### This is the uber script the arguements you give it decide what happens
## squirrel => Standard Query Ultracrepidate Iamatology Ruby Resource for Elasticsearch Labarum ##
# example commands:
# clear all caches
#    ruby squirrel.rb --host=localhost --port=9200 --clear_all_cache=true
# run slow log queries
#    ruby squirrel.rb --host=localhost --port=9200 --execute_slow_queries=/var/log/elasticsearch/padraig.log
# get backup an index aka generate a dumpfile
#    ruby squirrel.rb --host=localhost --port=9200 --output_dir="." --dump_index=flight_count_20130405 --batch_size=100 --dump_mapping=flight_count_20130405_mapping.json
# get the cardinatlity of a dumpfile(card_file)
#    ruby squirrel.rb --host=localhost --port=9200 --output_dir="." --card_file=flight_count_20130405 --cardinality=cnt,metric
# restore an index from a dumpfile
#    ruby squirrel.rb --host=localhost --port=9200 --outpu_dir="." --restore_file=flight_count_20130405.gz --restore_index=flight_count_20130405 --restore_mapping=flight_count_20130405_mapping.json --batch_size=100
# create a new index from a dumpfile
#    Ruby squirrel.rb --host=localhost --port=9200 --outpu_dir="." --restore_file=flight_count_20130405.gz --create_index=test_flight_count_20130405 --restore_mapping=flight_count_20130405_mapping.json --batch_size=100


require "configliere"
require_relative "../test/esbackup_stripped.rb"
require_relative "../squirrel/replay.rb"
require_relative "../test/warmer_interface.rb"
require_relative "../test/clear_es_caches.rb"
require_relative "../test/change_es_index_settings.rb"

Settings.use :commandline
Settings.use :config_block
Settings.define :output_dir,                                default: '',    description: 'Directory to put output, defaults to current path'
Settings.define :dump_file,                                 default: nil,   description: 'The name of the dumpfile to use, default is nil'
Settings.define :dump_index,                                default: nil,   description: 'Create dump of the given index, default is nil'
Settings.define :query,                                     default: nil,   description: 'Query to use in order to limit the data extracted from the index, default nil'
Settings.define :restore_index,                             default: nil,   description: 'Restore the given index from --dump_file, default is nil'
Settings.define :create_index,                              default: nil,   description: 'Create an index of the given name, default is nil'
Settings.define :duplicate_index,                           default: nil,   description: 'Duplicate the given index, defaults to nil'
Settings.define :restore_index,                             default: nil,   description: 'Restore the given index, defaults to nil'
Settings.define :restore_file,                              default: nil,   description: 'Dump file to use when restoring, defaults to nil'
Settings.define :cardinality,               :type => Array, default: nil,   description: 'Return the cardinality of the given index, defaults to nil'
Settings.define :card_file,                                 default: nil,   description: 'The dump file to grab info from when determining cardinality MUST NOT be compressed, defaults to nil'
Settings.define :warmers,                                   default: nil,   description: 'Use warmers expected values true/false, defaults to nil'
Settings.define :new_warmers_name,                          default: nil,   description: 'Name of warmer to create, defaults to nil'
Settings.define :create_warmer,                             default: nil,   description: 'Query to create warmer, defaults to nil'
Settings.define :remove_warmer,                             default: nil,   description: 'Name of warmer to remove, defaults to nil'
Settings.define :execute_slow_queries,                      default: nil,   description: 'Execute the slow log queries in the provided log file,ie --execute_slow_log=/var/log/elasticsearch/padraig.log, defaults to nil'
Settings.define :batch_size,                                default: nil,   description: 'Batch size when processing gzip file, defaults to nil'
Settings.define :dump_mapping,                              default: nil,   description: 'The name of the file in which to dump the indexes mapping, defaults to nil'
Settings.define :restore_mapping,                           defualt: nil,   description: 'The mapping json file to use when restoring the index, defaults to nil'
Settings.define :duplicate_mapping,                         default: nil,   description: 'The mapping json file to use when duplicating documents in an index, defaults to nil'
Settings.define :host,                                      default: nil,   description: 'The elasticsearch hostname, defaults to nil'
Settings.define :port,                                      default: 9200,  description: 'The port on the elasticsearch host to connect to, defaults to 9200'
Settings.define :clear_all_cache,                           default: nil,   description: 'Clear all caches expected true/false, defaults to nil'
Settings.define :clear_filter_cache,                        default: nil,   description: 'Clear filter cache expected true/false, defaults to nil'
Settings.define :clear_fielddata,                           default: nil,   description: 'Clear fielddata expected true/false, defaults to nil'
Settings.define :settings_index,                            default: nil,   description: 'The index that the settings listed in index_settings will be changed for, defaults to nil'
Settings.define :es_index_settings,         :type => Array, default: [],    description: 'A comma deliminated list of elasticsearch index settings to be set for --settings_index, defaults to []'
Settings.define :es_index_settings_values,  :type => Array, default: [],    description: 'A comma deliminated list of elasticsearch index settings values to be set for --settings_index, defaults to []'
Settings.resolve!


class Squirrel

  def initialize(options = {})
    ##The next two lines are necessary if you want to run without configliere, as they enforce the non-nil defaults
    #defaults = {:output_dir => '', :port => 9200}
    #options = defaults.merge(options)

    @output_dir = options[:output_dir]

    @dump_file = options[:dump_file]
    @dump_index = options[:dump_index]
    @restore_index = options[:restore_index]
    @create_index = options[:create_index]
    @duplicate_index = options[:duplicate_index]

    @restore_file = options[:restore_file]
    @restore_index = options[:restore_index]
    @cardinality = options[:cardinality]
    @card_file = options[:card_file]
    @warmers = options[:warmers]

    @new_warmers_name = options[:new_warmers_name]
    @create_warmer = options[:create_warmer]
    @remove_warmer = options[:remove_warmer]
    @execute_slow_queries = options[:execute_slow_queries]
    @batch_size = options[:batch_size]

    @dump_mapping = options[:dump_mapping]
    @restore_mapping = options[:restore_mapping]
    @duplicate_mapping = options[:duplicate_mapping]
    @host = options[:host]
    @port = options[:port]

    @clear_all_cache = options[:clear_all_cache]
    @clear_filter_cache = options[:clear_filter_cache]
    @clear_fielddata = options[:clear_fielddata]
    @settings_index = options[:settings_index]
    @settings = options[:es_index_settings]

    @settings_values = options[:es_index_settings_values]

  end

  def is_not_nil?(param)
    !param.nil?
  end

  def is_bool?(param)
    if !!param = param
      return true
    else
      return false
    end
  end

  def build_task_controllers
    @some_option_names = %w[dump_index dump_mapping restore_file restore_index restore_mapping create_index
        duplicate_index duplicate_mapping duplicate_index cardinality card_file new_warmers_name remove_warmer warmers
        create_warmer execute_slow_queries clear_all_cache clear_fielddata clear_filter_cache settings_index settings
        settings_values]
    #puts "\n"
    #puts @some_option_names.inspect
    @tasks = %w[backup backup restore restore restore restore restore duplicate duplicate cardinality cardinality warmer
                warmer warmer warmer replay cache cache cache index_settings index_settings index_settings]
    #puts @tasks.inspect
    @base_tasks_params = {:output_dir => @output_dir, :batch_size => @batch_size, :port => @port, :host => @host}

    @task_controllers = [@dump_index, @dump_mapping, @restore_file, @restore_index, @restore_mapping, @create_index,
                         @duplicate_index, @duplicate_mapping, @restore_index, @cardinality, @card_file,
                         @new_warmers_name, @remove_warmer, @warmers, @create_warmer, @execute_slow_queries,
                         @clear_all_cache, @clear_fielddata, @clear_filter_cache, @settings_index, @settings,
                         @settings_values].zip(@some_option_names, @tasks)
    puts "\n"
    @task_controllers.each do |pairs|
      puts pairs.inspect
    end
    @execute_tasks = {}
  end

  def add_task?(var, var_name, task_name)
    if is_not_nil?(var) && var != []
      @execute_tasks[task_name] ||= {}
      @execute_tasks[task_name][var_name.to_sym] = var
      unless @execute_tasks[task_name].has_key?(:cache)
        @execute_tasks[task_name].merge!(@base_tasks_params)
      end
    end
  end


  def determine_tasks
    @task_controllers.each do |var, var_sym, task|
      add_task?(var, var_sym, task)
    end
    puts @execute_tasks.inspect
  end

  def determine_warmer_action(options = {})
    if is_not_nil?(options[:remove_warmer])
      options[:action] = "remove_warmer"
      options[:warmer_name] = options[:remove_warmer]
      WarmerInterface.new(options).remove_warmer
    else
      if options[:warmer]
        options[:action] = "enable_warmer"
        WarmerInterface.new(options).enable_warmer
      else
        options[:action] = "disable_warmer"
        WarmerInterface.new(options).disable_warmer
      end
      unless options[:new_warmers_name].nil?
        options[:action] = "add_warmer"
        options[:warmer_name] = options[:new_warmers_name]
        options[:query] = options[:create_warmer]
        WarmerInterface.new(options).add_warmer
      end
    end
  end

  def determine_cache_clear(options = {})
    if options[:clear_all_cache]
      options[:type] = "all"
      ClearESCaches.new(options).run
    end
    if options[:clear_filter_cache]
      options[:type] = "filter"
      ClearESCaches.new(options).run
    end
    if options[:clear_fielddata]
      options[:type] = "fielddata"
      ClearESCaches.new(options).run
    end
  end

  def cardinality(options)
    options[:cardinality].each do |field|
      output = `ruby getFields.rb --dump=#{options[:card_file]} --field=#{field} >> #{field}.txt ;
        cat #{field}.txt |sort | uniq -c |sort -n | wc -l;`
      puts "The number of values in #{field} form file #{ooptions[:card_file]} is #{output}"
    end
  end

  def task_caller
    @execute_tasks.each do |task, options|
      puts task
      puts options.inspect
      case command = task.to_sym
        when :restore
          options[:index] = options[:restore_index]
          options[:mappings] = options[:restore_mapping]
          ESRestore.new(options[:restore_file], options).run
        when :backup
          options[:index] = options[:dump_index]
          options[:mappings] = options[:dump_mapping]
          ESBackup.new(options[:output_dir], options).run
        when :duplicate
          options[:index] = options[:duplicate_index]
          options[:mappings] = options[:duplicate_mapping]
          ESDup.new(options[:output_dir], options).run
        when :cardinality
          cardinality(options)
        when :warmer
          determine_warmer_action(options)
        when :replay
          puts options[:execute_slow_queries]
          Replay.new(options[:execute_slow_queries], options[:host], options[:port]).run
        when :cache
          determine_cache_clear(options)
        when :index_settings
          if is_not_nil?(options[:es_index_settings]) && is_not_nil?(options[:es_index_settings_values])
            options[:settings_and_values] = options[:es_index_settings].zip(options[:es_index_settings_values])
            ChangeESIndexSettings.new(options).run
          end
        else abort Settings.help("Must specify either backup, restore, duplicate, cardinality, warmer, replay, cache or index_settings.  Got <#{command}> UPDATE THIS LINE!")
      end
    end
  end

  def run
    build_task_controllers
    determine_tasks
    task_caller
  end
end

Squirrel.new(Settings.to_hash).run

