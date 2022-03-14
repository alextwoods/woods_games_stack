class Story
  include Aws::Record
  set_table_name 'woods-games-stories'
  string_attr :id, hash_key: true

  datetime_attr   :created_at
  datetime_attr   :updated_at

  string_attr :type
  integer_attr :live_date  # Date.jd / d.jd - julian date (number of days)

  string_attr :title
  string_attr :body

  string_attr :status

  string_attr :prompt
  string_attr :author_info

  list_attr :log

  def self.upcoming_news
    query(
      index_name: 'type-live_date-index',
      expression_attribute_names: { "#type" => "type", "#date" => "live_date" },
      expression_attribute_values: { ":type" => "news", ":date" => Date.today.jd },
      key_condition_expression: "#type = :type AND #date >= :date",
      scan_index_forward: true, # sort by most recent first
      )
  end

  def self.upcoming_today
    query(
      index_name: 'type-live_date-index',
      expression_attribute_names: { "#type" => "type", "#date" => "live_date" },
      expression_attribute_values: { ":type" => "today", ":date" => Date.today.jd },
      key_condition_expression: "#type = :type AND #date >= :date",
      scan_index_forward: true, # sort by most recent first
    )
  end

  # Override 'save' to set some timestamps automatically.
  def save(opts = {})
    self.created_at = Time.current unless created_at
    self.updated_at = Time.current
    super opts
  end

  # useful for bulk updating values, but allowing dirty value checks.
  def set_attrs(attr_values)
    attr_values.each do |attr_name, attr_value|
      send("#{attr_name}=", attr_value)
    end
    dirty
  end
end
