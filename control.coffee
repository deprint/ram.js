#A better Random Acces Machine in Coffeescript/Javascript
#Copyright (C) 2015      Fabian Stiewitz <fabian.stiewitz@gmail.com>
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

startRam = ->
  clearError()
  input = document.getElementById('ram_program')
  input_values = document.getElementById('input').value.split(/\s+/)
  abort = false
  input_val = []
  input_values.forEach (c) ->
    return if c is ''
    unless isNaN(n = parseInt(c))
      input_val.push n
      return
    showError("Could not parse integer: #{c}")
    abort = true
  machine = asl(input.value)
  if machine['input_layout']?
    return if abort
    if Object.keys(machine.input_layout).length isnt input_val.length
      console.log input_val
      console.log machine.input_layout
      return showError('INPUT layout does not match input string')
  else
    input_values = []
  return showError(machine.error) if machine.error isnt ''
  unless run(machine, input_val, 1000, true)
    displayOutput(machine)
    displayCode(machine)
    displayMem(machine)
    displaySnapshots(machine)
    showOutput()
  else
    showError(machine.error)

clearError = ->
  document.getElementById('error').classList.add 'hidden'

showError = (error) ->
  e = document.getElementById('error')
  e.innerHTML = error
  e.classList.remove 'hidden'
  document.getElementById('results').classList.add 'hidden'

showOutput = ->
  document.getElementById('results').classList.remove 'hidden'

regs =
  a: -4
  i1: -3
  i2: -2
  i3: -1
num_sort = (a, b) ->
  a = if regs[a]? then regs[a] else parseInt(a)
  b = if regs[b]? then regs[b] else parseInt(b)
  return -1 if a < b
  return 0 if a is b
  return 1 if a > b

displayOutput = (machine) ->
  output = get_output(machine)
  str = '<table><tr><th>Stelle</th><th>Wert</th></tr>'
  for key in Object.keys(output).sort(num_sort)
    str += "<tr><td>#{key}</td><td>#{output[key]}</td></tr>"
  document.getElementById('output').innerHTML = str + '</table>'

displayCode = (machine) ->
  code = get_code_stats(machine)
  total = 0
  str = '<table><tr><th>Zeile</th><th>#Aufrufe</th><th>Code</th></tr>'
  for key in Object.keys(code).sort(num_sort)
    total += code[key]
    str += "<tr><td>#{key}</td><td>#{code[key]}</td><td>#{get_line(machine, key)}</td></tr>"
  document.getElementById('code_stats').innerHTML = str + '</table>'
  document.getElementById('code_total').innerHTML = total + ' Aufrufe'

displayMem = (machine) ->
  mem = get_mem_stats(machine)
  total = [0, 0]
  str = '<table><tr><th>Stelle</th><th>#Lesen</th><th>#Schreiben</th></tr>'
  for key in Object.keys(mem).sort(num_sort)
    total[0] += mem[key][0]
    total[1] += mem[key][1]
    str += "<tr><td>#{key}</td><td>#{mem[key][0]}</td><td>#{mem[key][1]}</td></tr>"
  document.getElementById('mem_stats').innerHTML = str + '</table>'
  document.getElementById('mem_total').innerHTML = "#{total[0]} Lesen/#{total[1]} Schreiben"

displaySnapshots = (machine) ->
  snapshots = get_snapshots(machine)
  snapshot = get_first_memory_snapshot(machine)
  slots = Object.keys(snapshot).sort(num_sort)
  snapshot_ids = Object.keys(snapshots).sort(num_sort)

  str = '<table><tr><th>Zeitpunkt</th>'
  for id in slots
    str += "<th>#{id}</th>"
  str += '<th>Stelle</th><th>Zeile</th></tr>'
  str += '<tr><td>-</td>'
  for id in slots
    str += "<td>#{snapshot[id]}</td>"
  str += '<td>-</td><td>Ausgangspunkt</td></tr>'

  for id in snapshot_ids
    replay_snapshot(machine, snapshot, id, id)
    str += "<tr><td>#{id}</td>"
    for slot in slots
      str += "<td>#{snapshot[slot]}</td>"
    str += "<td>#{snapshots[id][0]}</td><td>#{get_line(machine, snapshots[id][0])}</td></tr>"

  document.getElementById('mem_snapshots').innerHTML = str + '</table>'
