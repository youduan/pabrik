require 'meta_search/exceptions'

module MetaSearch
  module Utility #:nodoc:
    private

    def array_of_arrays?(vals)
      vals.is_a?(Array) && vals.first.is_a?(Array)
    end

    def array_of_dates?(vals)
      vals.is_a?(Array) && vals.first.respond_to?(:to_time)
    end

    def cast_attributes(type, vals)
      if array_of_arrays?(vals)
        vals.map! {|v| cast_attributes(type, v)}
      # Need to make sure not to kill multiparam dates/times
      elsif vals.is_a?(Array) && (array_of_dates?(vals) || !(DATES+TIMES).include?(type))
        vals.map! {|v| cast_attribute(type, v)}
      else
        cast_attribute(type, vals)
      end
    end

    def cast_attribute(type, val)
      case type
      when *STRINGS
        val.respond_to?(:to_s) ? val.to_s : String.new(val)
      when *DATES
        if val.respond_to?(:to_date)
          val.to_date rescue nil
        else
          y, m, d = *[val].flatten
          m ||= 1
          d ||= 1
          Date.new(y,m,d) rescue nil
        end
      when *TIMES
        if val.respond_to?(:to_time)
          val.to_time rescue nil
        else
          y, m, d, hh, mm, ss = *[val].flatten
          Time.zone.local(y, m, d, hh, mm, ss) rescue nil
        end
      when *BOOLEANS
        ActiveRecord::ConnectionAdapters::Column.value_to_boolean(val)
      when :integer
        val.blank? ? nil : val.to_i
      when :float
        val.blank? ? nil : val.to_f
      when :decimal
        val.blank? ? nil : ActiveRecord::ConnectionAdapters::Column.value_to_decimal(val)
      else
        raise TypeCastError, "Unable to cast columns of type #{type}"
      end
    end

    def collapse_multiparameter_options(opts)
      opts.keys.each do |k|
        if k.include?("(")
          real_attribute, position = k.split(/\(|\)/)
          cast = %w(a s i).include?(position.last) ? position.last : nil
          position = position.to_i - 1
          value = opts.delete(k)
          opts[real_attribute] ||= []
          opts[real_attribute][position] = if cast
            (value.blank? && cast == 'i') ? nil : value.send("to_#{cast}")
          else
            value
          end
        end
      end
      opts
    end

    def quote_table_name(name)
      ActiveRecord::Base.connection.quote_table_name(name)
    end

    def quote_column_name(name)
      ActiveRecord::Base.connection.quote_column_name(name)
    end
  end
end