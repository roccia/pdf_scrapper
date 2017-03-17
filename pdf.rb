require 'rubygems'
require 'pdf/reader'
require 'active_record'
require 'mysql2'
require './cn_info'
class Pdf <  ActiveRecord::Base
   URL_PERFIX = "cninfo.com.cn"
  ActiveRecord::Base.establish_connection(
      adapter:  'mysql2',
      database: 'PDF',
      username: 'meiuser',
      password: '_m3iu$er_',
      host:     'localhost'
  )

  def self.get_data(*arg)
  res  = CnInfo.get_result(*arg)
  res.each do |s|
  PdfTest.create(:title => s[:title], :company_code => s[:code], :company_name => s[:name], :url => s[:url])
    end
  end


  def self.generate_url
     t =  PdfTest.where(:title => "2016年年度报告")
      t.each do |x|
         url = x.url
      end
  end


    #get_data("#{INDUSTRY[:农业]};#{INDUSTRY[:采矿业]}", PLATE[:深市主板], CATEGORY[:年度报告], "2017-01-01", "2017-03-12")




end

