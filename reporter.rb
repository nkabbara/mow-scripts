#TODO Add check if uploaded file update/create timestamp hasn'w been refreshed. Means report is out of date.
require 'csv'
require 'mail'
require 'date'
require 'action_view'
include ActionView::Helpers::NumberHelper

def send_email(body)
  mail = Mail.new do
    from     'nash@motorsonwheels.com'
    to       'nash@motorsonwheels.com,chad@motorsonwheels.com,joad@motorsonwheels.com'
    subject  "Sales Report for #{Time.now.strftime('%Y/%m/%d')}"
    body     body
    #add_file :filename => "trello-report-#{Date.today.to_s}.csv", :content => csv
  end
  mail.delivery_method :sendmail
  mail.deliver!
end

def money(amount)
 number_to_currency(amount, precision: 0)
end

available_cars = CSV.read('/home/mow/MoWAvailableVehicles.csv', skip_blanks: true, headers: true)
sold_cars = CSV.read('/home/mow/MoWSoldVehicles.csv', skip_blanks: true, headers: true)
sold_today_cars = sold_cars.select { |v| Date.strptime(v[11], '%m/%d/%y') == Date.today }
sold_month_to_date_cars = sold_cars.select { |v| Date.strptime(v[11], '%m/%d/%y').month == Date.today.month }

sold_unit_report =  sold_today_cars.collect { |c| "    #{c[5][0..6]} #{c[1]} #{c[2]} #{c[3]} **Profit:** $#{c[6]} **Days:** #{c[8]}" }.join("\n")

sum_today = 0 
sold_today_cars.each{ |row| sum_today += row[6].gsub(/\D/, '').to_f/100 }

sum_this_month = 0 
sold_month_to_date_cars.each{ |row| sum_this_month += row[6].gsub(/\D/, '').to_f/100 }

buyer_message = Time.now.saturday? ? "Buyer, add the number of deposits (if any) to #{ 150 - (available_cars.count - 1)}. That's your car purchase limit for next week. \nDo not change this number based on future sales.\nIf it's a negative number, then we're overstocked."  : "Buying limit will be available Saturday."
  

report = %{
  Total Cars Available: #{available_cars.count - 1}
  Today's Sales: #{sold_today_cars.count}
  Today's Total Profit: #{sum_today}
  Today's Profit/car: #{sold_today_cars.count.zero? ? 0 : money(sum_today/sold_today_cars.count)}
  Month To Date Sales: #{sold_month_to_date_cars.count}   
  Month To Date Profit/car: #{money(sum_this_month/sold_month_to_date_cars.count)}

  Units sold today: 
#{sold_today_cars.count.zero? ? '   None' : sold_unit_report}


#{buyer_message}
}

send_email(report)
