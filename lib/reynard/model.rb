# frozen_string_literal: true

class Reynard
  # Superclass for dynamic classes generated by the object builder.
  class Model < BasicObject
    extend ::Forwardable
    def_delegators :@attributes, :[]

    class << self
      # Holds references to the full schema for the model if available.
      attr_accessor :schema
      # The inflector to use on properties.
      attr_writer :inflector
    end

    def initialize(attributes)
      if attributes.respond_to?(:each)
        @attributes = {}
        @snake_cases = self.class.snake_cases(attributes.keys)
        self.attributes = attributes
      else
        ::Kernel.raise(
          ::ArgumentError,
          'Models must be initialized with an enumerable object that behaves like a hash, got: ' \
          "`#{attributes.inspect}'"
        )
      end
    end

    # We rely on these methods for various reasons so we re-introduce them at the expense of
    # allowing them to be used as attribute name for the model.
    %i[class is_a? nil? object_id kind_of? respond_to? send].each do |method|
      define_method(method, ::Kernel.method(method))
    end

    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)}>"
    end

    def attributes=(attributes)
      attributes.each do |name, value|
        @attributes[name.to_s] = self.class.cast(name, value)
      end
    end

    # Until we can set accessors based on the schema
    def method_missing(attribute_name, *)
      return false unless @attributes

      attribute_name = attribute_name.to_s
      if @attributes.key?(attribute_name)
        @attributes[attribute_name]
      else
        @attributes.fetch(@snake_cases.fetch(attribute_name))
      end
    rescue ::KeyError
      ::Kernel.raise ::NoMethodError, "undefined method `#{attribute_name}' for #{inspect}"
    end

    def respond_to_missing?(attribute_name, *)
      attribute_name = attribute_name.to_s
      return true if @attributes.key?(attribute_name)

      @snake_cases.key?(attribute_name) && @attributes.key?(@snake_cases[attribute_name])
    rescue ::NameError
      false
    end

    def try(attribute_name)
      respond_to_missing?(attribute_name) ? send(attribute_name) : nil
    end

    def self.cast(name, value)
      return if value.nil?
      return value unless schema

      property = schema.property_schema(name)
      return value unless property

      ::Reynard::ObjectBuilder.new(schema: property, inflector: inflector, parsed_body: value).call
    end

    def self.inflector
      @inflector ||= ::Reynard::Inflector.new
    end

    def self.snake_cases(property_names)
      property_names.each_with_object({}) do |property_name, snake_cases|
        snake_case = inflector.snake_case(property_name)
        next if snake_case == property_name

        snake_cases[snake_case] = property_name
      end
    end
  end
end
