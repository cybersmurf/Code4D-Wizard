unit C4D.Wizard.Memory.Vector;

{
  Ollama Embedding Client for Code4D Wizard Memory
  ==================================================
  Calls the Ollama /api/embeddings endpoint to produce 1024-dim float vectors
  using mxbai-embed-large (same model as emistr-dev-mcp).

  Falls back gracefully (returns empty slice) when Ollama is unreachable
  so that the memory system works in text-only mode without the embeddings
  server.

  Cosine similarity is also implemented here so Search can use it.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Math;

type
  TC4DWizardMemoryVectorizer = class
  private
    FEndpoint : string;   // e.g. 'http://192.168.220.6:11434'
    FModel    : string;   // e.g. 'mxbai-embed-large:latest'
    FEnabled  : Boolean;

    function BuildEmbeddingURL: string;
  public
    constructor Create(const AEndpoint: string = '';
      const AModel: string = 'mxbai-embed-large:latest');

    /// <summary>Get embedding vector for AText.
    /// Returns empty array when Ollama is not reachable.</summary>
    function GetEmbedding(const AText: string): TArray<Double>;

    /// <summary>Cosine similarity between two equal-length vectors.
    /// Returns 0 when either is nil/empty.</summary>
    class function CosineSimilarity(const A, B: TArray<Double>): Double;

    property Enabled: Boolean read FEnabled;
    property Endpoint: string read FEndpoint write FEndpoint;
    property Model: string read FModel write FModel;
  end;

implementation

constructor TC4DWizardMemoryVectorizer.Create(const AEndpoint, AModel: string);
begin
  FEndpoint := AEndpoint;
  FModel    := AModel;
  FEnabled  := not AEndpoint.IsEmpty;
end;

function TC4DWizardMemoryVectorizer.BuildEmbeddingURL: string;
begin
  Result := FEndpoint.TrimRight(['/']) + '/api/embeddings';
end;

function TC4DWizardMemoryVectorizer.GetEmbedding(
  const AText: string): TArray<Double>;
var
  LClient  : THTTPClient;
  LBody    : TStringStream;
  LResp    : IHTTPResponse;
  LRaw     : string;
  LRoot    : TJSONValue;
  LEmbArr  : TJSONArray;
  I        : Integer;
  LReq     : TJSONObject;
begin
  Result := [];
  if not FEnabled or AText.IsEmpty then Exit;

  LClient := THTTPClient.Create;
  LReq    := TJSONObject.Create;
  try
    LReq.AddPair('model', FModel);
    LReq.AddPair('prompt', AText);
    LBody := TStringStream.Create(LReq.ToJSON, TEncoding.UTF8);
    try
      LResp := LClient.Post(
        BuildEmbeddingURL, LBody, nil,
        [TNameValuePair.Create('Content-Type', 'application/json')]);
      if LResp.StatusCode <> 200 then Exit;
      LRaw := LResp.ContentAsString(TEncoding.UTF8);
    finally
      LBody.Free;
    end;

    LRoot := TJSONObject.ParseJSONValue(LRaw);
    try
      if not (LRoot is TJSONObject) then Exit;
      LEmbArr := (LRoot as TJSONObject).GetValue<TJSONArray>('embedding', nil);
      if not Assigned(LEmbArr) then Exit;
      SetLength(Result, LEmbArr.Count);
      for I := 0 to LEmbArr.Count - 1 do
        Result[I] := (LEmbArr.Items[I] as TJSONNumber).AsDouble;
    finally
      LRoot.Free;
    end;
  except
    Result := [];  // Ollama offline — silently degrade
  end;
  FreeAndNil(LClient);
  LReq.Free;
end;

class function TC4DWizardMemoryVectorizer.CosineSimilarity(
  const A, B: TArray<Double>): Double;
var
  Dot, NormA, NormB : Double;
  I                 : Integer;
begin
  Result := 0;
  if (Length(A) = 0) or (Length(A) <> Length(B)) then Exit;
  Dot := 0; NormA := 0; NormB := 0;
  for I := 0 to High(A) do
  begin
    Dot   := Dot   + A[I] * B[I];
    NormA := NormA + A[I] * A[I];
    NormB := NormB + B[I] * B[I];
  end;
  NormA := Sqrt(NormA);
  NormB := Sqrt(NormB);
  if (NormA = 0) or (NormB = 0) then Exit;
  Result := Dot / (NormA * NormB);
end;

end.
