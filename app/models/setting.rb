class Setting < ApplicationRecord
  self.primary_key = "entity_id"
  def as_json(options={})
    opts = {
      :only => [:results_shown, :tracking],
      :methods => []
    }
    super(options.merge(opts))
  end
end
