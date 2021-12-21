class Word
  include Aws::Record
  set_table_name 'woods-games-wordlist'

  string_attr :id, hash_key: true
  string_attr :word, range_key: true

  datetime_attr :updated_at

  def self.word_list(list)
    query(
      expression_attribute_values: {
        ":v1" => list.downcase,
      },
      key_condition_expression: "id = :v1"
    )
  end

  def save(opts = {})
    self.id = id.downcase
    self.word = word.downcase
    self.updated_at = Time.current
    super opts
  end
end
