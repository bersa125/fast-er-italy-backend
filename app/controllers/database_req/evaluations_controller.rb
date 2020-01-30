require 'date'
require 'json'

class DatabaseReq::EvaluationsController < ApplicationController
  
  # GET method to get all evaluations on an hospital
  def index
    required = [:firebase_token, :avg]
    if required.all? {|k| params.has_key? k} #http://localhost:3000/addresses?one=1&two=2&three=3
      # here you know params has all the keys defined in required array 
      data= get_user_id(params[:firebase_token])
      id=nil
      verified="false"
      unless data.nil?
        id = data["user_id"]
        verified = data["email_verified"]
      end
      unless id.nil? && verified == "false"
        user = User.new
        user.id = id
        if User.exists?(id: user.id)
          user = User.find(id)
        else
          user.save
        end
        if params[:avg] == "true" && params[:hospital_placename].present? && params[:hospital_address].present? #check an average
          evaluations= Evaluation.where("hospital = :hospital_searched AND address = :address_searched",{hospital_searched: params[:hospital_placename], address_searched: params[:hospital_address]})
          wait=evaluations.average("wait_vote")
          struct= evaluations.average("struct_vote")
          service=evaluations.average("service_vote")
          render :json => { :code => "500", :status => "OK", :message => "Done.", :avg_wait_vote => wait , :avg_struct_vote => struct , :avg_service_vote => service}
        else
          if params[:avg] == "false"
              evaluations = Evaluation.where("entity = :id",{id: user.id})
              render :json => { :code => "500", :status => "OK", :message => "Done.", :history => evaluations.as_json(root: false) }
          else
            render :json => { :code => "400", :status => "Error", :message => "Missing some params." }
          end
        end
      else
        render :json => { :code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => { :code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  # POST method for defining user addresses
  def create
    required = [:firebase_token, :hospital_placename, :hospital_address, :wait_vote, :struct_vote, :service_vote, :timestamp]
    if required.all? {|k| params.has_key? k} #http://localhost:3000/addresses?one=1&two=2&three=3
      # here you know params has all the keys defined in required array
      data= get_user_id(params[:firebase_token])
      id=nil
      verified="false"
      unless data.nil?
        id = data["user_id"]
        verified = data["email_verified"]
      end
      unless id.nil? && verified == "false"
        user = User.new
        user.id = id
        if User.exists?(id: user.id)
          user = User.find(id)
        else
          user.save
        end
        sub_date=DateTime.parse(params[:timestamp]) rescue sub_date=DateTime.parse("0001-01-01")
        if params[:wait_vote].to_i<=5 && params[:struct_vote].to_i<=5 && params[:service_vote].to_i<=5 && params[:wait_vote].to_i>=0 && params[:struct_vote].to_i>=0 && params[:service_vote].to_i>=0 && sub_date.today? && !Evaluation.where("entity = :id AND date = :passed_date AND hospital = :hospital_searched AND address = :address_searched ",{id: user.id, passed_date: params[:timestamp], hospital_searched: params[:hospital_placename], address_searched: params[:hospital_address]}).exists?
          submitted=0
          evaluations = Evaluation.where("entity = :id",{id: user.id})
          evaluations.each do |e|
            if e.created_at.today?
              submitted+=1
            end
          end
              if submitted<ENV['MAX_ALLOWED_DAILY_SUBMISSIONS'].to_i
                firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
               if Hospital.where("place_name = :passed_name AND address_name = :searched_address",{passed_name: params[:hospital_placename], searched_address: params[:hospital_address]}).exists?
                 hospital=Hospital.where("place_name = :passed_name AND address_name = :searched_address",{passed_name: params[:hospital_placename], searched_address: params[:hospital_address]}).take
                 usr_evaluation = Evaluation.new
                 usr_evaluation.date=sub_date.to_formatted_s(:iso8601)
                 usr_evaluation.hospital=hospital.place_name
                 usr_evaluation.entity=user.id
                 usr_evaluation.address=hospital.address_name
                 usr_evaluation.wait_vote=params[:wait_vote]
                 usr_evaluation.struct_vote=params[:struct_vote]
                 usr_evaluation.service_vote=params[:service_vote]
                 response = firebase.push("user/#{id}/votes", {hospital: usr_evaluation.hospital, address: usr_evaluation.address, wait_vote: usr_evaluation.wait_vote, struct_vote: usr_evaluation.struct_vote, service_vote: usr_evaluation.service_vote, timestamp: usr_evaluation.date, :created => Firebase::ServerValue::TIMESTAMP})
                 usr_evaluation.firebase_id =  (JSON.parse(response.raw_body)['name'])
                 response = firebase.push("hospital_votes", {hospital: usr_evaluation.hospital,address: usr_evaluation.address, wait_vote: usr_evaluation.wait_vote,struct_vote: usr_evaluation.struct_vote,service_vote: usr_evaluation.service_vote, :created => Firebase::ServerValue::TIMESTAMP})
                 usr_evaluation.firebase_id_public = (JSON.parse(response.raw_body)['name'])
                 usr_evaluation.save
                 render :json => {:code => "500", :status => "OK", :message => "Vote correctly submitted."}
                else
                   #create hospital
                   hospital=Hospital.new
                   hospital.place_name=params[:hospital_placename]
                   hospital.address_name=params[:hospital_address]
                   hospital.save
                   usr_evaluation = Evaluation.new
                   usr_evaluation.date=sub_date.to_formatted_s(:iso8601)
                   usr_evaluation.hospital=hospital.place_name
                   usr_evaluation.entity=user.id
                   usr_evaluation.address=hospital.address_name
                   usr_evaluation.wait_vote=params[:wait_vote]
                   usr_evaluation.struct_vote=params[:struct_vote]
                   usr_evaluation.service_vote=params[:service_vote]
                   response = firebase.push("user/#{id}/votes", {hospital: usr_evaluation.hospital,address: usr_evaluation.address, wait_vote: usr_evaluation.wait_vote,struct_vote: usr_evaluation.struct_vote,service_vote: usr_evaluation.service_vote, timestamp: usr_evaluation.date , :created => Firebase::ServerValue::TIMESTAMP})
                   usr_evaluation.firebase_id =  (JSON.parse(response.raw_body)['name'])
                   response = firebase.push("hospital_votes", {hospital: usr_evaluation.hospital,address: usr_evaluation.address, wait_vote: usr_evaluation.wait_vote,struct_vote: usr_evaluation.struct_vote,service_vote: usr_evaluation.service_vote, :created => Firebase::ServerValue::TIMESTAMP})
                   usr_evaluation.firebase_id_public = (JSON.parse(response.raw_body)['name'])
                   usr_evaluation.save
                   render :json => {:code => "500", :status => "OK", :message => "Vote correctly submitted (first)."}
                end
               else
                 render :json => {:code => "409", :status => "Conflict", :message => "Passed today's submission limit."}
               end
         else
           render :json => { :code => "400", :status => "Error", :message => "Unacceptable params."}
         end
      else
        render :json => {:code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => {:code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  # PUT method for updating in database an address (id in the link)
  def update
   required = [:firebase_token, :hospital_placename, :hospital_address, :wait_vote, :struct_vote, :service_vote, :timestamp]
    if required.all? {|k| params.has_key? k} #http://localhost:3000/addresses?one=1&two=2&three=3
      # here you know params has all the keys defined in required array
      data= get_user_id(params[:firebase_token])
      id=nil
      verified="false"
      unless data.nil?
        id = data["user_id"]
        verified = data["email_verified"]
      end
      unless id.nil? || verified == "false"
        if User.exists?(id: id)
          user = User.find(id)
          if params[:wait_vote].to_i<=5 && params[:struct_vote].to_i<=5 && params[:service_vote].to_i<=5 && params[:wait_vote].to_i>=0 && params[:struct_vote].to_i>=0 && params[:service_vote].to_i>=0
            sub_date=DateTime.parse(params[:timestamp]) rescue sub_date=DateTime.parse("0001-01-01")
            if Hospital.where("place_name = :passed_name AND address_name = :searched_address",{passed_name: params[:hospital_placename], searched_address: params[:hospital_address]}).exists?
              
              submitted=0
              evaluations = Evaluation.where("entity = :id",{id: user.id})
              evaluations.each do |e|
                if e.updated_at.today?
                  submitted+=1
                end
              end
              if submitted<ENV['MAX_ALLOWED_DAILY_MODIFICATIONS'].to_i
                if Evaluation.where("hospital = :hospital_searched AND address = :address_searched AND date = :time AND entity = :id ",{hospital_searched: params[:hospital_placename], address_searched: params[:hospital_address], time: sub_date.to_formatted_s(:iso8601), id: user.id}).exists?
                  firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
                  usr_evaluation=Evaluation.where("hospital = :hospital_searched AND address = :address_searched AND date = :time AND entity = :id ",{hospital_searched: params[:hospital_placename], address_searched: params[:hospital_address], time: sub_date.to_formatted_s(:iso8601), id: user.id}).take
                  firebase_new_id=nil
                  firebase_new_public_id=nil
                  unless usr_evaluation.firebase_id.nil?
                    response=firebase.update("user/#{id}/votes/#{usr_evaluation.firebase_id}",{wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], :created => Firebase::ServerValue::TIMESTAMP},[])       
                    if(response.code==400)
                      firebase.delete("user/#{id}/votes/#{usr_evaluation.firebase_id}",{})
                      response = firebase.push("user/#{id}/votes", {hospital: usr_evaluation.hospital, address: usr_evaluation.address, wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], timestamp: usr_evaluation.date, :created => Firebase::ServerValue::TIMESTAMP})
                      firebase_new_id=(JSON.parse(response.raw_body)['name'])
                    end                    
                  else
                    response = firebase.push("user/#{id}/votes", {hospital: usr_evaluation.hospital, address: usr_evaluation.address, wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], timestamp: usr_evaluation.date, :created => Firebase::ServerValue::TIMESTAMP})
                    firebase_new_id=(JSON.parse(response.raw_body)['name'])
                  end
                  unless usr_evaluation.firebase_id_public.nil?
                    response=firebase.update("hospital_votes/#{usr_evaluation.firebase_id_public}",{wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], :created => Firebase::ServerValue::TIMESTAMP},[])       
                    if(response.code==400)
                      firebase.delete("hospital_votes/#{usr_evaluation.firebase_id_public}",{})
                      response = firebase.push("hospital_votes", {hospital: usr_evaluation.hospital, address: usr_evaluation.address, wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], :created => Firebase::ServerValue::TIMESTAMP})
                      firebase_new_public_id=(JSON.parse(response.raw_body)['name'])
                    end
                  else
                    response = firebase.push("hospital_votes", {hospital: usr_evaluation.hospital, address: usr_evaluation.address, wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], :created => Firebase::ServerValue::TIMESTAMP})
                    firebase_new_public_id=(JSON.parse(response.raw_body)['name'])
                  end
                  unless firebase_new_id.nil?
                    unless firebase_new_public_id.nil?
                      usr_evaluation.update(wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], firebase_id: firebase_new_id,  firebase_id_public: firebase_new_public_id)
                    else
                      usr_evaluation.update(wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], firebase_id: firebase_new_id)
                    end
                  else
                    unless firebase_new_public_id.nil?
                      usr_evaluation.update(wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], firebase_id_public: firebase_new_public_id)
                    else
                      usr_evaluation.update(wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote])
                    end
                  end
                  render :json => {:code => "500", :status => "OK", :message => "Registered."}
                else
                  render :json => {:code => "204", :status => "No Content", :message => "Vote searched doesn't exists."}
                end
              else
                render :json => {:code => "409", :status => "Conflict", :message => "Passed today's edit limit."}
              end
            else
              render :json => {:code => "204", :status => "No Content", :message => "No vote exists for this hospital." }
            end
          else
            render :json => { :code => "400", :status => "Error", :message => "Unacceptable params."}
          end
        else
          render :json => {:code => "204", :status => "No Content", :message => "User hasn't published anything yet." }
        end
      else
        render :json => {:code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => {:code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  #DELETE (id in the link)
  def destroy
    required = [:firebase_token, :hospital_placename, :hospital_address, :timestamp]
    if required.all? {|k| params.has_key? k} #http://localhost:3000/addresses?one=1&two=2&three=3
      # here you know params has all the keys defined in required array
      data= get_user_id(params[:firebase_token])
      id=nil
      verified="false"
      unless data.nil?
        id = data["user_id"]
        verified = data["email_verified"]
      end
      unless id.nil? && verified == "false"
        if User.exists?(id: id)
          user = User.find(id)
          if Hospital.where("place_name = :passed_name AND address_name = :searched_address",{passed_name: params[:hospital_placename], searched_address: params[:hospital_address]}).exists?
            sub_date=DateTime.parse(params[:timestamp]) rescue sub_date=DateTime.parse("0001-01-01")
            unless sub_date.today?
              if Evaluation.where("hospital = :hospital_searched AND address = :address_searched AND date = :time AND entity = :id ",{hospital_searched: params[:hospital_placename], address_searched: params[:hospital_address], time: sub_date.to_formatted_s(:iso8601), id: user.id}).exists?
                firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
                usr_evaluation=Evaluation.where("hospital = :hospital_searched AND address = :address_searched AND date = :time AND entity = :id ",{hospital_searched: params[:hospital_placename], address_searched: params[:hospital_address], time: sub_date.to_formatted_s(:iso8601), id: user.id}).take
                response= firebase.delete("user/#{id}/votes/#{usr_evaluation.firebase_id}",{})
                if(response.code==200)
                  response=firebase.delete("hospital_votes/#{usr_evaluation.firebase_id_public}",{})
                  if(response.code==200)
                    usr_evaluation.destroy
                    render :json => {:code => "500", :status => "OK", :message => "Vote deleted." }
                  else
                    response = firebase.push("user/#{id}/votes", {hospital: usr_evaluation.hospital, address: usr_evaluation.address, wait_vote: params[:wait_vote], struct_vote: params[:struct_vote], service_vote: params[:service_vote], timestamp: usr_evaluation.date, :created => Firebase::ServerValue::TIMESTAMP})
                    usr_evaluation.update(firebase_id: (JSON.parse(response.raw_body)['name']))
                    render :json => {:code => "400", :status => "Error", :message => "Cannot delete from cloud storage." }
                  end
                else
                  render :json => {:code => "400", :status => "Error", :message => "Cannot delete from cloud storage." }
                end
              else
                render :json => {:code => "204", :status => "No Content", :message => "Vote pointed doesn't exists." }
              end
            else
              render :json => {:code => "204", :status => "No Content", :message => "Cannot delete votes submitted today." }
            end
          else
            render :json => {:code => "204", :status => "No Content", :message => "No vote exists for this hospital." }
          end
        else
          render :json => {:code => "204", :status => "No Content", :message => "User hasn't published anything yet." }
        end
      else
        render :json => {:code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => {:code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  #unused
  # GET method for editing a product based on id
  def edit
    render :json => {:code => "400", :status => "Error", :message => "Action not supported." }
  end
  
  # GET method to get a product by id
  def show
    render :json => {:code => "400", :status => "Error", :message => "Action not supported." }
  end
 
  # GET method for the new product form
  def new
    render :json => {:code => "400", :status => "Error", :message => "Action not supported." }
  end
  
  private
  
  def get_user_id(token)
    certificate_url = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    myresponse = RestClient.get(certificate_url).body
    certificates  = JSON.parse myresponse.gsub('=>', ':')
    myjson =""
    certificates.each do|key , value|
      begin
        x509 = OpenSSL::X509::Certificate.new(value)
        iss = "https://securetoken.google.com/#{ENV['FIREBASE_PROJECT_ID']}"
        aud = ENV['FIREBASE_PROJECT_ID']
        myjson = JWT.decode(token, x509.public_key, true, 
        {               algorithm: "RS256", verify_iat: true ,
                       iss: iss , verify_iss: true ,
                       aud: aud , verify_aud: true
        })
        return myjson[0]
      rescue
      end
    end
    return nil     
  end
end
