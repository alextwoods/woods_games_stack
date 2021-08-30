class Room
  include Aws::Record
  set_table_name 'woods-games-rooms'
  string_attr :id, hash_key: true

  datetime_attr   :created_date
  datetime_attr   :updated_date

  string_attr :passphrase

end