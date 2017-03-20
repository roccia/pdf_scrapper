require 'json'
require 'rest-client'
require 'rubygems'
require 'pdf/reader'
require 'active_record'
require 'mysql2'
require 'open-uri'

class CnInfo < ActiveRecord::Base
  validates_uniqueness_of :url

  URL = "http://www.cninfo.com.cn/cninfo-new/announcement/query"
  URL_PERFIX = "http://www.cninfo.com.cn"
  INDUSTRY = {:农业 => "农、林、牧、渔业",
              :采矿业 => "采矿业",
              :制造业 => "制造业",
              :供应业 => "电力、热力、燃气及水生产和供应业",
              :建筑业 => "建筑业",
              :批发和零售业 => "批发和零售业",
              :交通运输 => "交通运输、仓储和邮政业",
              :住宿和餐饮业 => "住宿和餐饮业",
              :信息传输 => "信息传输、软件和信息技术服务业",
              :金融业 => "金融业",
              :房地产业 => "房地产业",
              :租赁和商务服务业 => "租赁和商务服务业",
              :科学研究和技术服务业 => "科学研究和技术服务业",
              :公共设施管理业 => "水利、环境和公共设施管理业",
              :居民服务修理和其他服务业 => "居民服务、修理和其他服务业",
              :教育 => "教育",
              :卫生和社会工作 => "卫生和社会工作",
              :娱乐业 => "文化、体育和娱乐业",
              :综合 => "综合"
  }

  PLATE = {:深市公司 => "sz",
           :深市主板 => "szmb",
           :中小板 => "szzx",
           :创业板 => "szcy",
           :沪市主板 => "shmb"
  }

  CATEGORY = {
      :年度报告 => "category_ndbg_szsh",
      :半年度报告 => "category_bndbg_szsh",
      :一季度报告 => "category_yjdbg_szsh",
      :三季度报告 => "category_sjdbg_szsh",
      :首次公开发行 => "category_scgkfx_szsh",
      :配股 => "category_pg_szsh",
      :增发 => "category_zf_szsh",
      :可转换债券 => "category_kzhz_szsh",
      :权证相关 => "category_qzxg_szsh",
      :其他融资 => "category_qtrz_szsh",
      :权益及限制出售 => "category_qyfpxzcs_szsh",
      :股权变动 => "category_gqbd_szsh",
      :交易 => "category_jy_szsh",
      :股东大会 => "category_gddh_szsh",
      :澄清分析业绩预告 => "category_cqfxyj_szsh",
      :特别处理和退市 => "category_tbclts_szsh",
      :补充及更正 => "category_bcgz_szsh",
      :中介机构报告 => "category_zjjg_szsh",
      :上市公司制度 => "category_ssgszd_szsh",
      :债券公告 => "category_zqgg_szsh",
      :其他重大事项 => "category_qtzdsx_szsh",
      :投资者关系 => "category_tzzgx_szsh",
      :董事会公告 => "category_dshgg_szsh",
      :监事会公告 => "category_jshgg_szsh"
  }


  def self.first_page(*arg)
    params = {
        stock: '',
        searchkey: '',
        plate: "#{arg[1]}",
        category: "#{arg[2]}",
        trade: "#{arg[0]}",
        column: 'szse_main',
        columnTitle: '历史公告查询',
        pageNum: p,
        pageSize: 50,
        tabName: 'fulltext',
        seDate: "#{arg[3]} ~ #{arg[4]}"
    }
    response = RestClient.post(URL, params)
    res = JSON.parse response.body
    total_num = res["totalAnnouncement"]
    total_num
  end

  def self.get_result(*arg)
    ary = []
    res = first_page(*arg)
    industry = arg[0]
    plate = arg[1]
    category = arg[2]
    if res < 50
      pages = res
    else
      pages = (res/50.to_f).round
    end
    pages.times do |p|
      params = {
          stock: '',
          searchkey: '',
          plate: "#{arg[1]}",
          category: "#{arg[2]}",
          trade: "#{arg[0]}",
          column: 'szse_main',
          columnTitle: '历史公告查询',
          pageNum: p,
          pageSize: 50,
          tabName: 'fulltext',
          seDate: "#{arg[3]} ~ #{arg[4]}"
      }

      begin
        response = RestClient.post(URL, params)
      rescue RestClient::ExceptionWithResponse => err
        p "#############{err.response}############"
      end

      rs = JSON.parse response
      if rs.present?
        p '############查询开始############'
      else
        p '############网络问题，请重试############'
      end

      rs["announcements"].each do |s|
        announcementTitle = s["announcementTitle"]
        commpany_code = s["secCode"]
        commpany_name = s["secName"]
        adjunctUrl = s["adjunctUrl"]
        p "$$$$$$$$$$$$ 开始读取PDF $$$$$$$$$$$$$$"
        content = read_pdf("#{URL_PERFIX}/#{adjunctUrl}")
        p "$$$$$$$$$$$$PDF内容为：#{content}$$$$$$$$$$$$$$"
        ary << {:industry => industry,
                :plate => plate,
                :category => category,
                :title => announcementTitle,
                :code => commpany_code,
                :name => commpany_name,
                :url => "#{URL_PERFIX}/#{adjunctUrl}",
                :content => content
        }
      end
    end
    ary
  end

  def self.read_pdf(url)
    content_ary = []
    io = open(url)
    reader = PDF::Reader.new(io)
    reader.pages.each do |page|
      content = page.text
      content_ary << content
    end
    content_ary
  end

  def self.save_to_db(res)
    begin
      ActiveRecord::Base.establish_connection(
          adapter: 'mysql2',
          database: 'cn_infos',
          username: 'root',
          password: '000000',
          host: 'localhost'
      )
      ActiveRecord::Base.connection.active?
      p "############数据库连接成功，开始导入数据############"
    rescue Exception => e
      p "Exception db connection :  #{e.message} "
      raise "数据库连接失败"
    end

    res.each do |s|
      CnInfo.create(:industry => s[:industry], :plate => s[:plate], :category => s[:category], :title => s[:title], :company_code => s[:code], :company_name => s[:name], :url => s[:url], :content => s[:content])
    end
  end

  def self.read_line
    puts "选择行业----------"
    puts "行业列表：#{INDUSTRY.keys}"
    puts '-----------'
    a = gets.chomp
    i_ary = a.split(',')
    s = i_ary.map { |i| INDUSTRY[i.to_sym] }
    industry = s.map(&:inspect).join(';')

    puts "选择板块----------"
    puts "板块列表：#{PLATE.keys}"
    puts '-----------'
    b = gets.chomp
    p_ary = b.split(',')
    ps = p_ary.map { |i| PLATE[i.to_sym] }
    plate = ps.map(&:inspect).join(';')

    puts "选择报告类型----------"
    puts "报告列表：#{CATEGORY.keys}"
    puts '-----------'
    c = gets.chomp
    report = CATEGORY[c.to_sym]

    puts "选择起始时间----------"
    start_time = gets.chomp
    puts "选择结束时间----------"
    end_time = gets.chomp

    res = get_result(industry, plate, report, start_time, end_time)
    save_to_db(res)
  end

  read_line

end


