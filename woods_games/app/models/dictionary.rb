class Dictionary
  include Aws::Record
  set_table_name 'woods-games-dictionary'

  string_attr :word, hash_key: true
  string_attr :def

end
