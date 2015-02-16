require 'csv'
require 'mail'
require 'date'
require 'action_view'

include ActionView::Helpers::NumberHelper

class Car
  attr_reader :_date_sold, :vin, :year, :make, :model, :profit, :days, :sale_type, :warranty_profit

  #Takes a row from the DMS csv file
  def initialize(car_row)
    @year      = car_row[1]
    @make      = car_row[2]
    @model     = car_row[3]
    @vin       = car_row[5]
    @profit    = clean_number(car_row[6])
    @days      = car_row[8]
    @_date_sold      = car_row[11]
    @sale_type       = car_row[12].blank? ? :cash : :finance
    @warranty_profit = clean_number(car_row[13])
  end

  def vin6
    vin[0..6]
  end

  def date_sold
    Date.strptime(@_date_sold, '%m/%d/%y')
  end

  private
  #Remove all weird chars that DMS tends to insert into numbers
  def clean_number(num)
    return 0.0 if num.blank?
    num.gsub(/[^0-9-]/, '').to_f/100 
  end

end

class Dealership
  #Change these on production to point to the FTP dir where DMS uploads the files.
  AVAILABLE_CARS_PATH = './MoWAvailableVehiclesSample.csv'
  SOLD_CARS_PATH      = './MoWSoldVehiclesSample.csv'
  attr_reader :todays_sold_cars

  def initialize
    options = { skip_blanks: true, headers: true }
    @available_cars   = CSV.read(AVAILABLE_CARS_PATH, options).collect { |row| Car.new(row) }
    @sold_cars        = CSV.read(SOLD_CARS_PATH, options).collect { |row| Car.new(row) }
    @todays_sold_cars = @sold_cars.select { |car| car.date_sold == Date.today }
    @month_to_date_sold_cars = @sold_cars.select { |car| car.date_sold.month == Date.today.month }
  end

  # -1 is because DMS has a boat that is not counted in MoW's inventory.
  def available_car_count
    @available_cars.count - 1
  end

  def todays_sold_count
    @todays_sold_cars.count
  end

  def todays_warranty_sold_count
    todays_sold_car_count_with { self.warranty_profit > 0 }
  end

  def todays_cash_count
    todays_sold_car_count_with { self.sale_type == :cash }
  end

  def todays_finance_count
    todays_sold_car_count_with { self.sale_type == :finance }
  end

  def todays_profit(formatted = false)
    @_todays_profit ||= @todays_sold_cars.inject(0.0){ |sum, car| sum + car.profit }
    format_money(formatted, @_todays_profit)
  end

  def month_to_date_profit(formatted = false)
    @_month_to_date_profit ||= @month_to_date_sold_cars.inject(0.0){ |sum, car| sum + car.profit }
    format_money(formatted, @_month_to_date_profit)
  end

  def todays_profit_per_car(formatted = false)
    total = todays_profit/todays_sold_count
    format_money(formatted, total)
  end

  def month_to_date_sold_count
    @month_to_date_sold_cars.count
  end

  def month_to_date_cash_count
    month_to_date_sold_car_count_with { self.sale_type == :cash }
  end

  def month_to_date_finance_count
    @_month_to_date_finance_count ||= month_to_date_sold_car_count_with { self.sale_type == :finance }
  end

  def month_to_date_warranty_count
    @_month_to_date_warranty_count ||= month_to_date_sold_car_count_with { self.warranty_profit > 0 }
  end

  def month_to_date_warranty_percentage
   (month_to_date_warranty_count * 100)/ month_to_date_finance_count 
  end

  def month_to_date_profit_per_car(formatted = false)
    total = month_to_date_profit/month_to_date_sold_count
    format_money(formatted, total)
  end

  private

  def todays_sold_car_count_with(&block)
    x_time_sold_cars_with(@todays_sold_cars, block)
  end

  def month_to_date_sold_car_count_with(&block)
    x_time_sold_cars_with(@month_to_date_sold_cars, block)
  end

  #We're really passing around a proc, not a block here
  def x_time_sold_cars_with(cars, block)
    cars.inject(0) { |count, car| car.instance_eval(&block) ? (count + 1) : count }
  end

  def format_money(formatted, amount)
    formatted ? number_to_currency(amount, precision: 0) : amount
  end
end

#Report formatting related methods.
module Reporter
  def self.sold_car_details(cars)
    cars.collect do |car| 
      "        #{car.vin6} #{car.year} #{car.make} #{car.model} **Profit:** $#{car.profit} **Days:** #{car.days}" 
    end.join("\n")
  end

  def self.saturday_message(car_count)
    "Buyer, add the number of deposits (if any) to #{ 150 - (car_count - 1)}. That's your car purchase limit for next week.      \nDo not change this number based on future sales.     \nIf it's a negative number, then MoW is overstocked."
  end

  def self.buyer_message(car_count)
    Time.now.saturday? ?  saturday_message(car_count) : "Buying limit will be available Saturday."
  end

  def self.build_report(dealership)
    %{
      Total Cars Available: #{dealership.available_car_count}
      Today's Car Sales: #{dealership.todays_sold_count} (#{dealership.todays_cash_count} cash and #{dealership.todays_finance_count} financed)
      Today’s Warranty Sales: #{dealership.todays_warranty_sold_count}
      Today's Total Profit: #{dealership.todays_profit(true)}
      Today's Profit/Car: #{dealership.todays_profit_per_car(true)}
      Month To Date Sales: #{dealership.month_to_date_sold_count} (#{dealership.month_to_date_cash_count} cash and #{dealership.month_to_date_finance_count} financed)
      Month To Date Warranty Sales: #{dealership.month_to_date_warranty_count} (#{dealership.month_to_date_warranty_percentage}% of financed cars)
      Month To Date Profit/Car: #{dealership.month_to_date_profit_per_car(true)}

      Units sold today: 
#{dealership.todays_sold_count.zero? ? '       None' : sold_car_details(dealership.todays_sold_cars)}


      #{buyer_message(dealership.available_car_count)}
    }
  end

end

module DailyReporter
  def self.env
    :test
  end

  def self.send_email(body)
    mail = Mail.new do
      from     'fake@domain.com'
      to       'fake@domain.com'
      subject  "Sales Report for #{Time.now.strftime('%Y/%m/%d')}"
      body     body
    end
    mail.delivery_method :sendmail
    env == :test ? puts(body) : mail.deliver!
  end

  def self.run
    dealership = Dealership.new
    report     = Reporter.build_report(dealership)
    send_email(report)
  end
end

if DailyReporter.env == :test
  Date.class_eval do
    def self.today
      Date.new(2015, 2, 13)
    end
  end
end


DailyReporter.run
