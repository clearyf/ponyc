use "files"
use "process"

actor Main
  let _env: Env
  var _labels: Array[U64] = Array[U64]()

  new create(env: Env) =>
    _env = env
    try
      let auth = _env.root as AmbientAuth
      let path = FilePath(auth, "/usr/bin/sleep")?
      var i: U64 = 0
      while i < _env.args(1)?.u64()? do
        start_process(i, auth, path)
        _labels.push(i)
        i = i + 1
      end
      _env.out.print("Started processes")
    else
      _env.out.print("Number of processes to start is a required argument!")
    end

  fun start_process(i: U64, auth: AmbientAuth, path: FilePath) =>
    let args = recover Array[String](3) end
    args.push("sleep")
    args.push("0.01")
    let pm = ProcessMonitor(auth, auth, ProcessClient(_env, this, i), path, consume args, _env.vars())
    pm.done_writing()

  be finished_ok(label: U64) =>
    _env.out.print("Finished: " + label.string())
    try
      let i = _labels.find(label)?
      _labels.delete(i)?
      if _labels.size() == 0 then
        _env.out.print("All finished")
      else
        let s = recover String() end
        s.append("Still running: ")
        for v in _labels.values() do
          s.append(v.string() + " ")
        end
        _env.out.print(consume s)
      end
    else
      _env.out.print("Couldn't find this label: " + label.string())
    end

class ProcessClient is ProcessNotify
  let _env: Env
  let _main: Main
  let _label: U64

  new iso create(env: Env, main: Main, label: U64) =>
    _env = env
    _main = main
    _label = label

  fun ref stdout(process: ProcessMonitor, data: Array[U8] iso) =>
    None

  fun ref stderr(process: ProcessMonitor, data: Array[U8] iso) =>
    None

  fun ref failed(process: ProcessMonitor, err: ProcessError) =>
    _env.out.print("ProcessError!")

  fun ref dispose(process: ProcessMonitor, child_exit_code: I32) =>
    if child_exit_code != 0 then
      _env.out.print("Child exit code: " + child_exit_code.string())
    end
    _main.finished_ok(_label)

  fun ref log(str: String) =>
    _env.out.print("proc " + _label.string() + " " + str)
