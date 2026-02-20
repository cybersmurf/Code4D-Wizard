# RTL (Run-Time Library) Patterns

## String Handling
```pascal
// ✅ TStringBuilder for concatenation in loops
var SB := TStringBuilder.Create;
try
  for var I := 1 to 1000 do
    SB.Append(IntToStr(I)).Append(',');
  Result := SB.ToString;
finally
  SB.Free;
end;

// ✅ Format for composition (type-safe, readable)
var Msg := Format('Customer %s (ID %d) — balance: %.2f', [Name, ID, Balance]);

// ✅ TRegEx for pattern matching
if TRegEx.IsMatch(Email, '^[\w.+-]+@[\w-]+\.[a-z]{2,}$', [roIgnoreCase]) then
  // valid email
```

## Collections (Generics)
```pascal
// ✅ TList<T> — ordered, type-safe
var List := TList<Integer>.Create;
try
  List.Add(42);
  List.Sort;
  for var V in List do Process(V);
finally
  List.Free;
end;

// ✅ TDictionary<K,V> with owned values
var Cache := TObjectDictionary<string, TDataObject>.Create([doOwnsValues]);
try
  Cache.Add('key', TDataObject.Create);
  // values freed automatically with the dictionary
finally
  Cache.Free;
end;

// ✅ TQueue<T> / TStack<T> for FIFO/LIFO
var Q := TQueue<string>.Create;
try
  Q.Enqueue('first');
  var Item := Q.Dequeue;
finally
  Q.Free;
end;
```

## File & Path Operations
```pascal
// ✅ TFile / TDirectory / TPath (System.IOUtils)
TFile.WriteAllText('output.txt', Content, TEncoding.UTF8);
var Lines := TFile.ReadAllLines('data.csv', TEncoding.UTF8);

var FullPath := TPath.Combine(BaseDir, RelPath);
var Ext      := TPath.GetExtension(FullPath).ToLower;
var FileName := TPath.GetFileNameWithoutExtension(FullPath);

if TFile.Exists(FullPath) then
  TFile.Delete(FullPath);
TDirectory.CreateDirectory(OutputDir);
```

## Streams
```pascal
// ✅ TMemoryStream for in-memory data
var MS := TMemoryStream.Create;
try
  MS.LoadFromFile('data.bin');
  MS.Position := 0;
  // read from stream
finally
  MS.Free;
end;

// ✅ TStringStream for text ↔ stream conversion
var SS := TStringStream.Create(JsonText, TEncoding.UTF8);
try
  HttpRequest.SourceStream := SS;
finally
  SS.Free;
end;
```

## JSON (System.JSON)
```pascal
// ✅ Parse JSON
var Root := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
if Assigned(Root) then
try
  var Name := Root.GetValue<string>('name');
  var Age  := Root.GetValue<Integer>('age');
finally
  Root.Free;
end;

// ✅ Build JSON
var Obj := TJSONObject.Create;
try
  Obj.AddPair('name', TJSONString.Create(Name));
  Obj.AddPair('age',  TJSONNumber.Create(Age));
  Result := Obj.ToJSON;
finally
  Obj.Free;
end;
```

## Date & Time
```pascal
// ✅ Use System.DateUtils for comparisons
var DaysDiff := DaysBetween(Date1, Date2);
var IsToday  := SameDate(SomeDate, Today);
var Next     := IncDay(Now, 7);

// ✅ ISO 8601 formatting / parsing
var ISO := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
```

## Best Practices
- Use `TStringBuilder` instead of `+` in loops
- Use `TObjectList<T>` / `TObjectDictionary<K,V>` with `OwnsObjects` to avoid manual cleanup
- Use `TPath` / `TFile` / `TDirectory` instead of old `FileExists` / `CreateDir` functions
- Use `TEncoding.UTF8` explicitly — never rely on system default encoding for files
- Prefer `TJSONObject.GetValue<T>` over manual cast chains
- Use `System.DateUtils` helpers rather than manual date arithmetic
