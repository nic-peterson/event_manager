require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

BAD_PHONE_NUMBER = "0000000000"

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def send_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone_number)
  stripped_phone_number = phone_number.gsub(/[-.() ]/, '')
  length = stripped_phone_number.length

  case length
  when 0...10
    stripped_phone_number = BAD_PHONE_NUMBER
  when 10
    stripped_phone_number
  else
    if (stripped_phone_number[0] = "1")
      stripped_phone_number = stripped_phone_number[1..-1]
    else
      stripped_phone_number = BAD_PHONE_NUMBER
    end
  end
  return stripped_phone_number
end

def identify_peak_hours(registration_hours)
  peak_hour = registration_hours.max_by { |_hour, count| count }
  peak_hour[0] # Return only the hour, not the count
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
registration_hours = Hash.new(0)
registration_days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  phone_number = clean_phone_number(row[:homephone])
  # peak_hours = identify_peak_hours(row[:regdate])
  registration_date = Time.strptime(row[:regdate], "%m/%d/%y %H:%M")
  # registration_date = Time.parse(row[:regdate])
  hour = registration_date.hour
  registration_hours[hour] += 1

  # put peak_hours

  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  send_thank_you_letter(id, form_letter)
end

puts "The peak registration hour begins at: #{identify_peak_hours(registration_hours)}:00"
