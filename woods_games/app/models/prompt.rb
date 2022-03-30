class Prompt
  include Aws::Record
  set_table_name 'woods-games-prompts'

  string_attr :id, hash_key: true
  string_attr :prompt
  string_attr :type

  datetime_attr :created_at

  def save(opts = {})
    self.created_at = Time.current unless created_at
    super opts
  end
end
