#
#Motors On Wheels Service Department handles inspecting and repairing any cars
#that require repair before placing them on the market. This scripts helps make 
#sure that things are getting done.
#
#Script looks for cards (cars) in the Unprocessed list in the Service
#department board. Every card that doesn't have a standard task checklist
#or Final Inspection checklist will get one added to it.
#

require "rubygems"
require_relative "mow_service_board"

include Trello

STD_TASKS = [
  "Enter in DMS",
  "Print & attach as-is guide",
  "Add key tag to Casey",
  "Get new inspection sticker",
  "Check gas, oil, tire pressure & coolant by Detail",
  "Add gas if needed",
  "Detail vehicle",
  "Take Photos",
  "Upload, Describe, upload photos, & price vehicle in marketing software"
]

FI_TASKS = [
  "Verified that all items in 'Checklist' are completed correctly by the vendors",
  'Verified that oil level is good and that oil is in good shape BEFORE driving the car',
  'Checked general exterior condition: RUST, paint, windshield, bumpers, wheels...',
  'Checked inpsection sticker for expiration (see wiki for details)',
  'Checked that as-is guide (buyers guide) is attached to the car',
  'Checked that decals are installed and in the right places (specially after body work.)',
  'Checked Sunroof (check this off if no sunroof)',
  "Checked remote control and it's working fine",
  'Verified that tires are in decent shape',
  "Verified that headlights are clear (don't need buffing)",
  'Checked that spare tire jack and toolkit are there',
  'Verified that blinkers & headlights work fine',
  'Checked general interior condition: upholstery, knobs, matts...',
  'Verified that all windows go up and down ',
  'Verified that driver & passenger seats move and adjust with no issues.',
  'Checked if A/C is cooling',
  'Made sure that windshield wipers work fine',
  'Made sure that radio & C/D player work fine',
  'Verified that airbag light & check engine light are not on',
  'Made sure that brakes & rotors are in good shape',
  'Listened for weird sounds and noises'
]


module MoWServiceBoard
  def self.add_my_checklist(name, items, card, board_id)
    checklist = Checklist.new('name' => name, "idBoard" => board_id)
    checklist.save
    items.each { |i| checklist.add_item(i) }
    card.add_checklist(checklist)
  end

  def self.run
    unprocessed_list = List.find(MoWServiceBoard.trello_unprocessed_list_id)
    unprocessed_list.cards.each do |card|

      unless card.checklists.any? { |cl| cl.name == "Standard Tasks" }
        add_my_checklist("Standard Tasks", STD_TASKS, card, MoWServiceBoard.trello_board_id)
      end

      unless card.checklists.any? { |cl| cl.name == "Final Inspection" }
        add_my_checklist("Final Inspection", FI_TASKS, card, BOARD_ID)
      end

    end
  end
end

MoWServiceBoard.run
