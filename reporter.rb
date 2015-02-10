require 'csv'
require 'mail'
require 'date'
require 'action_view'

include ActionView::Helpers::NumberHelper

class Car
  attr_reader :_date_sold, :vin, :year, :make, :model, :_profit, :inventory_days

  def initialize(car_row)
    @year      = car_row[1]
    @make      = car_row[2]
    @model     = car_row[3]
    @vin       = car_row[5]
    @_profit   = car_row[6]
    @days      = car_row[8]
    @_date_sold = car_row[11]
  end

  def vin6
    vin[0..6]
  end

  def profit
    _profit.gsub(/[^0-9-]/, '').to_f/100 
  end

  def date_sold
    Date.strptime(@_date_sold, '%m/%d/%y')
  end

end

class Dealership
  #Change these on production to point to the FTP dir where DMS uploads the files.
  AVAILABLE_CARS_PATH = './MoWAvailableVehiclesSample.csv'
  SOLD_CARS_PATH      = './MoWSoldVehiclesSample.csv'
  attr_reader :todays_sold_cars

  def initialize
    options = { skip_blanks: true, headers: true }
    @available_cars  = CSV.read(AVAILABLE_CARS_PATH, options).collect { |row| Car.new(row) }
    @sold_cars       = CSV.read(SOLD_CARS_PATH, options).collect { |row| Car.new(row) }
    @todays_sold_cars = @sold_cars.select { |car| car.date_sold == Date.today }
    @sold_month_to_date_cars = @sold_cars.select { |car| car.date_sold.month == Date.today.month }
  end

  def available_car_count
    # -1 is because DMS has a boat that we don't count in MoW's inventory.
    @available_cars.count - 1
  end

  def todays_sold_count
    @todays_sold_cars.count
  end

  def todays_profit(formatted = false)
    @_todays_profit ||= @todays_sold_cars.inject(0.0){ |sum, car| sum + car.profit }
    format_money(formatted, @_todays_profit)
  end

  def month_to_date_profit(formatted = false)
    @_month_to_date_profit ||= @sold_month_to_date_cars.inject(0.0){ |sum, car| sum + car.profit }
    format_money(formatted, @_month_to_date_profit)
  end

  def todays_profit_per_car(formatted = false)
    total = todays_profit/todays_sold_count
    format_money(formatted, total)
  end

  def month_to_date_sold_count
    @sold_month_to_date_cars.count
  end

  def month_to_date_profit_per_car(formatted = false)
    total = month_to_date_profit/month_to_date_sold_count
    format_money(formatted, total)
  end

  private

  def format_money(formatted, amount)
    formatted ? number_to_currency(amount, precision: 0) : amount
  end
end

module Reporter
  def self.sold_car_details(cars)
    cars.collect do |car| 
      "    #{car.vin6} #{car.year} #{car.make} #{car.model} **Profit:** $#{car.profit} **Days:** #{car.inventory_days}" 
    end.join("\n")
  end

  def self.buyer_message(car_count)
    Time.now.saturday? ? "Buyer, add the number of deposits (if any) to #{ 150 - (car_count - 1)}. That's your car purchase limit for next week. \nDo not change this number based on future sales.\nIf it's a negative number, then we're overstocked."  : "Buying limit will be available Saturday."
  end
end

module Emailer
  def self.send_email(body)
    mail = Mail.new do
      from     'fake@domain.com'
      to       'fake@domain.com'
      subject  "Sales Report for #{Time.now.strftime('%Y/%m/%d')}"
      body     body
    end
    mail.delivery_method :sendmail
    mail.deliver!
    puts body
  end
end

dealership = Dealership.new

report = %{
  Total Cars Available: #{dealership.available_car_count}
  Today's Sales: #{dealership.todays_sold_count}
  Today's Total Profit: #{dealership.todays_profit(true)}
  Today's Profit/car: #{dealership.todays_profit_per_car(true)}
  Month To Date Sales: #{dealership.month_to_date_sold_count}   
  Month To Date Profit/car: #{dealership.month_to_date_profit_per_car(true)}

  Units sold today: 
#{dealership.todays_sold_count.zero? ? '   None' : Reporter.sold_car_details(dealership.todays_sold_cars)}


  #{Reporter.buyer_message(dealership.available_car_count)}
}

Emailer.send_email(report)
