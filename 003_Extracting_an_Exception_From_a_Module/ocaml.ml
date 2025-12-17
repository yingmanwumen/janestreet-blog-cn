module Unix : sig
  type error

  exception Unix_error of error * string * string
end = struct
  type error

  exception Unix_error of error * string * string
end

module My_unix = struct
  include (
    Unix :
    sig
      exception Unix_error of Unix.error * string * string
    end)
end
