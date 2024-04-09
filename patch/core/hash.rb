#EXTEND HASH CLASS
class Hash
  def merge_recursively!(arg_other)
    self.merge!(arg_other) do |key, current_value, other_value|
      #Continue merging hash in a lower level
      if current_value.is_a? Hash \
      and other_value.is_a? Hash
        current_value.merge_recursively!(other_value)

      #Merge values
      else
        other_value.nil? ? current_value : other_value
      end
    end
  end

  def merge_recursively(arg_other)
    self.merge(arg_other) do |key, current_value, other_value|
      #Continue merging hash in a lower level
      if current_value.is_a? Hash \
      and other_value.is_a? Hash
        current_value = current_value.merge_recursively(other_value)

      #Merge values
      else
        current_value = other_value.nil? ? current_value : other_value
      end
    end
  end
end