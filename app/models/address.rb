class Address < ApplicationRecord #address:string latitude:decimal longitude:decimal
  self.primary_key = "address"
  def as_json(options={})
    opts = {
      :only => [:address, :latitude, :longitude],
      :methods => []
    }
    super(options.merge(opts))
  end
  
end
