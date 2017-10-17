module Emfrp
  module Typing
    class UnionType
      class UnifyError < RuntimeError
        attr_reader :a, :b
        def initialize(a, b)
          @a, @b = a, b
        end
      end
      NameCounter = (0..10000).to_a
      attr_reader :typename, :typeargs
      attr_accessor :name_id, :original_typevar_name, :union


      def self.from_type(type, tbl={})
        case type
        when Emfrp::Type
          new(type[:name][:desc], type[:args].map{|a| from_type(a, tbl)})
        when TypeVar
          name = type[:name][:desc]
          if tbl[name]
            tbl[name]
          else
            a = new()
            tbl[name] = a
            a.original_typevar_name = name
            a
          end
        when UnionType
          type
        else
          raise "unexpected type #{type.class} (bug)"
        end
      end

      def initialize(*args)
        if args.length == 2
          @typename = args[0]
          @typeargs = args[1]
        elsif args.length == 0
          @union = [self]
          @name_id = NameCounter.shift
          @original_name_id = @name_id
        else
          raise "Wrong number of arguments (#{args.length} for 0, 2)"
        end
      end

      def var?
        @union
      end

      def match?(other)
        if self.var? && other.var?
          self.name_id == other.name_id
        elsif !self.var? && !other.var?
          if self.typename == other.typename && self.typeargs.size == other.typeargs.size
            self.typeargs.zip(other.typeargs).all?{|a, b| a.match?(b)}
          else
            false
          end
        else
          false
        end
      end

      def include?(other)
        if self.match?(other)
          true
        elsif !self.var?
          self.typeargs.any?{|x| x.include?(other)}
        else
          false
        end
      end

      def has_var?
        if self.var?
          true
        else
          self.typeargs.any?{|x| x.has_var?}
        end
      end

      def unite(a, b)
        new_union = (a.collect_union + b.collect_union).uniq
        substitute_id = new_union.map{|t| t.name_id}.min
        new_union.each{|t| t.name_id = substitute_id}
        a.union = new_union
        b.union = new_union
      end

      def collect_union(visited={})
        return [] if visited[self]
        visited[self] = true
        res = @union + @union.map{|t| t.collect_union(visited)}.flatten
        return res.uniq
      end

      def typevars
        if var?
          [self]
        else
          typeargs.map{|t| t.typevars}.flatten
        end
      end

      def transform(other)
        @typename = other.typename
        @typeargs = other.typeargs
        @union = nil
      end

      def clone_utype(tbl={})
        if self.var?
          if tbl[self]
            tbl[self]
          else
            alt = self.class.new
            self.union.each{|t| tbl[t] = alt}
            alt
          end
        else
          self.class.new(self.typename, self.typeargs.map{|t| t.clone_utype(tbl)})
        end
      end

      def unify(other)
        if !self.var? && !other.var?
          if self.typename == other.typename && self.typeargs.size == other.typeargs.size
            self.typeargs.zip(other.typeargs).each{|t1, t2| t1.unify(t2)}
          else
            raise UnifyError.new(nil, nil)
          end
        elsif !self.var? && other.var?
          other.collect_union.each do |t|
            self.occur_check(t)
            t.transform(self)
          end
        elsif self.var? && !other.var?
          self.collect_union.each do |t|
            other.occur_check(t)
            t.transform(other)
          end
        else
          self.unite(self, other)
        end
      rescue UnifyError => err
        raise UnifyError.new(self, other)
      end

      def occur_check(var)
        if !self.var?
          self.typeargs.each{|t| t.occur_check(var)}
        end
        if self == var
          raise UnifyError.new(nil, nil)
        end
      end

      def to_uniq_str
        if self.var?
          raise "error"
        end
        if self.typeargs.size > 0
          args = self.typeargs.map{|t| t.to_uniq_str}.join(", ")
          "#{self.typename}[#{args}]"
        else
          "#{self.typename}"
        end
      end


      def to_flatten_uniq_str
        if self.var?
          raise "error"
        end
        if self.typeargs.size > 0
          args = self.typeargs.map{|t| t.to_flatten_uniq_str}.join("_")
          "#{self.typename}_#{args}"
        else
          "#{self.typename}"
        end
      end

      def inspect
        if self.var?
          #"a#{self.name_id}[#{@original_name_id}]" + (@original_typevar_name ? "(#{@original_typevar_name})" : "")
          "a#{self.name_id}" + (@original_typevar_name ? "(#{@original_typevar_name})" : "")
        else
          args = self.typeargs.size > 0 ? "[#{self.typeargs.map{|t| t.inspect}.join(", ")}]" : ""
          "#{self.typename}#{args}"
        end
      end
    end
  end
end
