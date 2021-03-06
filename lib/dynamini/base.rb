require_relative 'batch_operations'
require_relative 'querying'
require_relative 'client_interface'
require_relative 'dirty'
require_relative 'increment'
require_relative 'type_handler'
require_relative 'attributes'
require_relative 'errors'

module Dynamini
  # Core db interface class.
  class Base
    include ActiveModel::Validations
    extend ActiveModel::Callbacks
    extend Dynamini::BatchOperations
    extend Dynamini::Querying
    extend Dynamini::TypeHandler
    include Dynamini::ClientInterface
    include Dynamini::Dirty
    include Dynamini::Increment
    include Dynamini::Attributes

    class_attribute :handles

    self.handles = {
        created_at: {format: :time, options: {}},
        updated_at: {format: :time, options: {}}
    }

    define_model_callbacks :save

    alias :read_attribute_for_serialization :send

    class << self

      attr_reader :range_key, :secondary_index

      def table_name
        @table_name ||= name.demodulize.tableize
      end

      def set_table_name(name)
        @table_name = name
      end

      def set_hash_key(key, format = nil)
        @hash_key = key
        handle(key, format) if format
      end

      def set_range_key(key, format = nil)
        @range_key = key
        handle(key, format) if format
      end

      def set_secondary_index(index_name, args)
        @secondary_index ||= {}
        @secondary_index[index_name.to_s] = {hash_key_name: args[:hash_key] || hash_key, range_key_name: args[:range_key]}
      end

      def hash_key
        @hash_key || :id
      end

      def create(attributes, options = {})
        model = new(attributes, true)
        model if model.save(options)
      end

      def create!(attributes, options = {})
        model = new(attributes, true)
        model if model.save!(options)
      end
    end

    #### Instance Methods

    def initialize(attributes = {}, new_record = true)
      @new_record = new_record
      @attributes = {}
      clear_changes
      attributes.each do |k, v|
        write_attribute(k, v, change: new_record)
      end
    end

    def keys
      [self.class.hash_key, self.class.range_key]
    end

    def ==(other)
      hash_key == other.hash_key if other.is_a?(self.class)
    end

    def save(options = {})
      run_callbacks :save do
        @changes.empty? || (valid? && trigger_save(options))
      end
    end

    def save!(options = {})
      run_callbacks :save do
        options[:validate] = true if options[:validate].nil?

        unless @changes.empty?
          if (options[:validate] && valid?) || !options[:validate]
            trigger_save(options)
          else
            raise StandardError, errors.full_messages
          end
        end
      end
    end

    def touch(options = {validate: true})
      raise RuntimeError, 'Cannot touch a new record.' if new_record?
      if (options[:validate] && valid?) || !options[:validate]
        trigger_touch
      else
        raise StandardError, errors.full_messages
      end
    end

    def delete
      delete_from_dynamo
      self
    end

    private

    def trigger_save(options = {})
      generate_timestamps! unless options[:skip_timestamps]
      save_to_dynamo
      clear_changes
      @new_record = false
      true
    end

    def trigger_touch
      generate_timestamps!
      touch_to_dynamo
      true
    end

    def generate_timestamps!
      self.updated_at = Time.now.to_f
      self.created_at = Time.now.to_f if new_record?
    end

    def key
      key_hash = {self.class.hash_key => @attributes[self.class.hash_key]}
      key_hash[self.class.range_key] = @attributes[self.class.range_key] if self.class.range_key
      key_hash
    end

    def self.create_key_hash(hash_value, range_value = nil)
      key_hash = {self.hash_key => handled_key(self.hash_key, hash_value)}
      key_hash[self.range_key] = handled_key(self.range_key, range_value) if self.range_key
      key_hash
    end
  end
end
