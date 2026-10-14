module CCPathfinding
  # Minimal binary min-heap keyed by an integer priority.
  # Flat array storage: entries are [priority, payload] pairs.
  class BinaryHeap
    def initialize
      @entries = []
    end

    # Tell if the heap holds no entry
    # @return [Boolean]
    def empty?
      return @entries.empty?
    end

    # Number of stored entries
    # @return [Integer]
    def size
      return @entries.size
    end

    # Remove every entry
    def clear
      @entries.clear
    end

    # Insert a payload with the given priority
    # @param priority [Integer] sort key, smallest pops first
    # @param payload [Object] value returned by pop
    def push(priority, payload)
      @entries.push([priority, payload])
      sift_up(@entries.size - 1)
    end

    # Remove and return the payload with the smallest priority
    # @return [Object, nil] nil when the heap is empty
    def pop
      return nil if @entries.empty?

      top = @entries.first
      last = @entries.pop
      unless @entries.empty?
        @entries[0] = last
        sift_down(0)
      end

      return top[1]
    end

    private

    # Move the entry at index up until the heap property is restored
    # @param index [Integer] position of the entry to move
    def sift_up(index)
      entry = @entries[index]
      while index > 0
        parent_index = (index - 1) / 2
        parent = @entries[parent_index]
        break if parent[0] <= entry[0]

        @entries[index] = parent
        index = parent_index
      end

      @entries[index] = entry
    end

    # Move the entry at index down until the heap property is restored
    # @param index [Integer] position of the entry to move
    def sift_down(index)
      entry = @entries[index]
      half = @entries.size / 2
      while index < half
        child_index = index * 2 + 1
        right_index = child_index + 1
        child_index = right_index if right_index < @entries.size && @entries[right_index][0] < @entries[child_index][0]
        break if @entries[child_index][0] >= entry[0]

        @entries[index] = @entries[child_index]
        index = child_index
      end

      @entries[index] = entry
    end
  end
end
