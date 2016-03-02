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

starteRam = ->
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

asl = (input) ->
  machine =
    code: {}
    lines: {}
    error: ''
  ip = -1
  for line in input.split('\n')
    line = line.trim()
    continue if line is ''
    [n_ip, value] = ast(line, machine, ip)
    break unless value?
    continue if n_ip is -1
    ip = n_ip
    machine.code[ip] = value
  machine

run = (machine, input, limit = -1, snapshots) ->
  machine['input'] = input
  machine['error'] = ''
  machine['ip'] = 0
  machine['steps'] = 0
  machine['memory'] = {}
  machine['stats'] =
    command_usage: {}
    memory_usage: {}
  machine['snaps'] = {} if snapshots?

  if machine['input_layout']?
    for key in Object.keys(machine['input_layout'])
      machine.memory[machine.input_layout[key]] = machine.input[key] ? 0

  while limit is -1 or machine.steps < limit
    current = machine.code[machine.ip]
    return machine.error = "Reached nocode at #{machine.ip} step #{machine.steps}" unless current?

    unless machine.stats.command_usage[machine.ip]?
      machine.stats.command_usage[machine.ip] = 0

    ++machine.stats.command_usage[machine.ip]

    machine.snaps[machine.steps] = [machine.ip] if snapshots

    return machine.error unless _eval(current, machine, 0, snapshots)

    ++machine.ip
    ++machine.steps

  if limit > 0 and machine.steps is limit
    return machine.error = "Reached op limit at #{machine.ip}(aborted after #{limit} ops)"
  return ''

get_output = (machine) ->
  ret = {}
  for id in machine.output_layout
    ret[id] = machine.memory[id]
  return ret

get_code_stats = (machine) ->
  machine.stats.command_usage

get_mem_stats = (machine) ->
  machine.stats.memory_usage

get_line = (machine, id) ->
  machine.lines[id]

get_first_memory_snapshot = (machine) ->
  snapshot = {}
  snapshots = get_snapshots(machine)

  for k in Object.keys(snapshots)
    continue unless snapshots[k][1]
    snapshot[snapshots[k][1]] = 0

  if machine['input_layout']?
    for key in Object.keys(machine['input_layout'])
      id = machine['input_layout'][key]
      snapshot[id] = if (c = machine['input'][id])? then c else 0

  return snapshot

get_snapshots = (machine) ->
  machine.snaps

replay_snapshot = (machine, memory, from, to) ->
  for d in [from..to]
    step = machine.snaps[d]
    continue unless step?
    memory[step[1]] = step[2]

ast = (input, machine, ip) ->
  input = input.replace(/\/\/.+$/, '')
  input = input.trim()

  ++ip
  if (m = /^(\d+):\s*(.+)/.exec(input))?
    ip = m[1]
    input = m[2]

  while machine.code[ip]?
    ++ip

  if (m = /^(INPUT|OUTPUT)(.+)$/.exec(input))?
    if m[2] is ''
      machine.error = "#{ip}> #{m[1]} expects an argument"
      return [-1]

    ret = ast_eval_io(m[2], machine)
    if m[1] is 'INPUT'
      machine['input_layout'] = ret
    else
      machine['output_layout'] = ret
    return [-1, ret]

  machine.lines[ip] = input

  return [ip, get_ast(input, machine, ip)]

ast_eval_io = (input, machine) ->
  if input.indexOf(' ') isnt -1
    parms = input.split(/\s+/)
    ret = []

    for p in parms
      continue if p is ''
      r = ast_eval_io(p, machine)
      return unless r?
      ret = ret.concat r

    if ret.length is 0
      machine.error = 'Command expects argument'
    return ret
  else
    if (m = /^(\d+)\.\.(\d+)$/.exec(input))?
      ret = []
      ret.push i for i in [m[1]..m[2]]
      return ret
    else if (m = /^(\d+)$/.exec(input))?
      return [m[1]]
    else
      machine.error = "Argument not numeric: #{input}"

get_ast = (input, machine, ip) ->
  if (m = /^(\-?\d+(?:\.\d+)?)$/.exec(input))
    ast_imm(m[1])
  else if (m = /^(a|i|i1|i2|i3)$/.exec(input))
    ast_reg(if m[1] is 'i' then 'i1' else m[1])
  else if (m = /^s\[\s*(.+?)\s*\]$/.exec(input))
    ast_mem(m[1], machine, ip)
  else if (m = /^jump\s+(.+)$/.exec(input))
    ast_jump(m[1], machine, ip)
  else if (m = /^(.+?)\s*<--?\s*(.+?)$/.exec(input))
    ast_assign(m[1], m[2], machine, ip)
  else if (m = /^(.+?)\s*(<|<=|!?=|>=|>)\s*0$/.exec(input))
    ast_cond(m[1], m[2], machine, ip)
  else if (m = /^if\s+(.+?)\s+then\s+(.+)$/.exec(input))
    ast_cond_jump(m[1], m[2], machine, ip)
  else if (m = /^(.+?)\s*(\+|\-|\*|div|mod)\s*(.+)$/.exec(input))
    ast_algo(m[1], m[2], m[3], machine, ip)
  else if (input is 'HALT')
    return ['halt']
  else
    machine.error = "Unknown input: #{input}"
    return

ast_imm = (imm) ->
  ['imm', imm]

ast_reg = (reg) ->
  ['reg', reg]

algo_right =
  imm: 1
  mem: 1
  mmem: 1
ast_algo = (left, op, right, machine, ip) ->
  return unless (left = get_ast(left, machine, ip))?
  return unless (right = get_ast(right, machine, ip))?

  unless left[0] is 'reg'
    return report(machine, "#{ip}> Expected reg, got: #{left[0]}(#{left})")

  unless algo_right[right[0]]?
    return report(machine, "#{ip}> Expected imm, mem or mmem, got: #{right[0]}(#{right})")

  type = left[1] is 'a'
  unless(type or (right[0] is 'imm' and (op is '+' or op is '-')))
    return report(machine, "#{ip}> Index register only allows addition or subtraction with imm (#{left}#{op}#{right}")

  return ['algo', type, left, op, right]

ast_mem = (input, machine, ip) ->
  return unless (inner = get_ast(input, machine, ip))

  return ['mem', inner[1]] if inner[0] is 'imm'

  if inner[0] is 'algo'
    unless inner[1] is 0
      return report(machine, "#{ip}> Cannot use register a in mmem (#{input})")
    return ['mmem', inner]
  else if (inner[0] is 'reg') and (inner[1] isnt 'a')
    return ['mmem', inner]
  else return report(machine, "#{ip}> Expected imm, algo or index register, got: #{inner[0]}(#{input})")

ast_cond = (_reg, op, machine, ip) ->
  return unless (reg = get_ast(_reg, machine, ip))

  unless(reg[0] is 'reg')
    return report(machine, "#{ip}> Expected reg, got: #{reg[0]}(#{_reg})")

  return ['cond', reg, op]

ast_jump = (input, machine, ip) ->
  return unless (dest = get_ast(input, machine, ip))

  unless(dest[0] is 'imm')
    return report(machine, "#{ip}> Expected imm, got: #{dest[0]}(#{input})")

  return ['jump', dest]

ast_cond_jump = (_cond, instr, machine, ip) ->
  return unless(cond = get_ast(_cond, machine, ip))

  unless(cond[0] is 'cond')
    return report(machine, "#{ip}> Expected cond, got: #{cond[0]}(#{_cond})")

  return unless(jump = get_ast(instr, machine, ip))

  unless(jump[0] is 'jump')
    return report(machine, "#{ip}> Expected jump, got: #{jump[0]}(#{instr})")

  return ['if', cond, jump]

assign_right =
  imm: 1
  mem: 1
  reg: 1
assign_a_right =
  mmem: 1
  algo: 1
ast_assign = (_left, _right, machine, ip) ->
  return unless (left = get_ast(_left, machine, ip))
  return unless (right = get_ast(_right, machine, ip))

  if left[0] is 'reg'
    rcheck = assign_right[right[0]]?

    if left[1] is 'a'
      unless(rcheck or assign_a_right[right[0]]?)
        return report(machine, "#{ip}> Expected imm, reg, mem, mmem or algo, got: #{right[0]}(#{_right})")
    else
      unless(rcheck or right[0] is 'algo')
        return report(machine, "#{ip}> Expected imm, reg, mem or algo, got: #{right[0]}(#{_right})")
      unless((not right[1]) or right[0] isnt 'algo')
        return report(machine, "#{ip}> register a not allowed in i(1|2|3) assignment (#{_right})")
  else if left[0] is 'mem'
    unless(right[0] is 'reg')
      return report(machine, "#{ip}> Expected reg, got: #{right[0]}(#{_right})")
  else if left[0] is 'mmem'
    unless(right[0] is 'reg' and right[1] is 'a')
      return report(machine, "#{ip}> Expected register a, got: #{right[0]}(#{_right})")
  else return report(machine, "#{ip}> Expected reg, mem or mmem, got: #{left[0]}(#{_left})")
  return ['assign', left, right]

eval_imm = (ast) ->
  parseInt(ast[1])

eval_mem = (ast, machine, type = 0) ->
  unless machine.memory[ast[1]]?
    machine.memory[ast[1]] = 0

  inc_mem_stat(machine, ast[1], type)

  return parseInt(machine.memory[ast[1]]) unless type > 0
  return ast[1]

eval_mmem = (ast, machine, type = 0) ->
  return unless (val = _eval(ast[1], machine))?
  return eval_mem(['mem', val], machine, type)

eval_algo = (ast, machine) ->
  return unless (left = _eval(ast[2], machine))?
  return unless (right = _eval(ast[4], machine))?

  if ast[3] is '+'
    return left + right
  else if ast[3] is '-'
    return left - right
  else if ast[3] is '*'
    return left * right
  else if ast[3] is 'div'
    return parseInt(left / right)
  else if ast[3] is 'mod'
    return left % right
  else
    machine.error = "Operator not supported: #{ast[3]}"
    return

eval_cond = (ast, machine) ->
  return unless (val = _eval(ast[1], machine))?

  if ast[2] is '<'
    return val < 0
  else if ast[2] is '<='
    return val <= 0
  else if ast[2] is '='
    return val is 0
  else if ast[2] is '!='
    return val isnt 0
  else if ast[2] is '>='
    return val >= 0
  else if ast[2] is '>'
    return val > 0
  else
    machine.error = "Operator not supported: #{ast[2]}"
    return

eval_if = (ast, machine) ->
  return unless (cond = _eval(ast[1], machine))?
  eval_jump(ast[2], machine) if cond
  return 1

eval_jump = (ast, machine) ->
  return unless (val = _eval(ast[1], machine))?
  machine.ip = val - 1
  return 1

eval_assign = (ast, machine) ->
  return unless (left = _eval(ast[1], machine, 1))?
  return unless (right = _eval(ast[2], machine))?
  machine.memory[left] = right
  add_snapshot(machine, left, right) if machine.snaps
  return 1

eval_funcs =
  imm: eval_imm
  reg: eval_mem
  mem: eval_mem
  mmem: eval_mmem
  algo: eval_algo
  cond: eval_cond
  if: eval_if
  jump: eval_jump
  assign: eval_assign
_eval = (ast, machine, args...) ->
  if ast[0] is 'halt'
    return
  if eval_funcs[ast[0]]?
    return eval_funcs[ast[0]](ast, machine, args)
  else
    machine.error = "AST Element #{ast[0]} not supported"
    return

inc_mem_stat = (machine, addr, type) ->
  return if type is 2
  unless(machine.stats.memory_usage[addr])?
    machine.stats.memory_usage[addr] = [0, 0]
  ++machine.stats.memory_usage[addr][if type > 0 then 1 else 0]

add_snapshot = (machine, addr, value) ->
  machine.snaps[machine.steps].push addr
  machine.snaps[machine.steps].push value

report = (machine, message) ->
  console.log message
  machine.error = message
  return
