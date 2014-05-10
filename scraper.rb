require 'nokogiri'
require 'mechanize'
require 'pp'

Mechanize.html_parser = Nokogiri::HTML

BASE_URL = "http://www.ytj.fi/english/"

def get_metadata(key, default)
    begin
      ScraperWiki.get_var(key, default)
    rescue Exception => e
        puts "ERROR: #{e.inspect} during get_metadata(#{key}, #{default})"
    end
end

def save_metadata(key, value)
    begin
      ScraperWiki.save_var(key, value)
    rescue Exception => e
        puts "ERROR: #{e.inspect} during save_metadata(#{key}, #{default})"
    end
end

def text(str)
  begin
      return (str.nil? or str.text.nil?) ? "" : Iconv.conv("UTF-8","UTF-8",str.text.gsub(/\n|\t|^\s+|\s+$/,""))
  rescue Exception => e
      return str.text unless str.nil? 
      puts e.backtrace
  end
end

def attributes(t,attr)
  return (t.nil? or t.first.nil? or t.first.attributes.nil?) ? "" : t.first.attributes[attr].value
end

def scrape(data,action)
  if action == "list"
    records = []
    Nokogiri::HTML(data).xpath("//div[@id='search-result']/table/tr[position()>1]").each{|tr|
      td = tr.xpath("td")
      r =  {
         "COMPANY_NUMBER" => text(td[0].xpath("a")),
         "URL" => BASE_URL + attributes(td[0].xpath("a"),"href"),
         "COMPANY_NAME" => text(td[1]),
         "TYPE" => text(td[2]),
         "DOC" => Time.now.to_s
      } 
      records << r unless r["COMPANY_NUMBER"].nil? or r["COMPANY_NUMBER"].empty? 
      #puts records.inspect
    }
      ScraperWiki.save_sqlite(unique_keys=["COMPANY_NUMBER","TYPE"],records,table_name="CMPLIST") unless records.empty? 
  end
end

def scraped(params)
  return get_metadata(params,nil)
end

def action(srch)
  begin
    br = Mechanize.new { |b|
      b.user_agent_alias = 'Linux Firefox'
    }
    pg_num = 1
    params = { 
      "_ctl0:ContentPlaceHolder:hakusana" => srch,
      "_ctl0:ContentPlaceHolder:ytunnus" => "",
      "_ctl0:ContentPlaceHolder:yrmu" => "",
      "_ctl0:ContentPlaceHolder:sort" => "sort1",
      "_ctl0:ContentPlaceHolder:suodatus" => "suodatus2",
      "_ctl0:ContentPlaceHolder:hidsortorder" => "2",
      "__EVENTTARGET" => "_ctl0:ContentPlaceHolder:CollectionPager1"
    }
    s_url = BASE_URL + "yrityshaku.aspx"
    pg = br.get(s_url)
    begin
      pg.form_with(:name => "aspnetForm") do |f|
        params.each{|k,v|
          f[k] = v
        }
        pg =  f.submit
      end
      scrape(pg.body,"list")
      pg_num = pg_num +1
      params["__EVENTARGUMENT"] = pg_num
    rescue Exception => e
      puts "ERROR: While processing #{srch} :: #{e.inspect} :: #{e.backtrace}"
    end while pg.at("a[text()='\302\240|\302\240Seuraava']")
    save_metadata("SRCH_STRING",srch.next)
  end
end

range = ('AAA'..'ZZZZ').to_a + ('000'..'999').to_a
offset = get_metadata("OFFSET",0)
offset = 0 if offset >= range.length
range.each_with_index{|srch,idx|
  begin
    next if idx < offset
    action(srch)
    save_metadata("OFFSET",idx.next)
  rescue Exception => e
    puts "ERROR: While processing #{srch} :: #{e.inspect} :: #{e.backtrace}"
    sleep(10)
  end
}