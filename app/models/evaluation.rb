class Evaluation < ApplicationRecord
  self.primary_key = "date"
  def as_json(options={})
    opts = {
      :only => [:date, :hospital, :address, :wait_vote, :struct_vote, :service_vote],
      :methods => []
    }
    super(options.merge(opts))
  end
end
