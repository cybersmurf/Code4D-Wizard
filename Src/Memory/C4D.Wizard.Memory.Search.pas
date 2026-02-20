unit C4D.Wizard.Memory.Search;

{
  Semantic + Text Search for Code4D Wizard Memory
  =================================================
  Combines two scoring signals:
    1. Vector cosine similarity (Ollama embeddings) — weight 0.6
    2. Text FTS score (word-overlap / substring) — weight 0.4

  When Ollama is unavailable (no embedding in stored entry or vectorizer
  returns empty), the score falls back to text-only (weight 1.0).

  Results are returned sorted by combined score descending.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  C4D.Wizard.Memory.Types,
  C4D.Wizard.Memory.Storage,
  C4D.Wizard.Memory.Vector;

type
  TC4DWizardMemorySearch = class
  private
    FStorage    : TC4DWizardMemoryStorage;  // not owned
    FVectorizer : TC4DWizardMemoryVectorizer; // not owned

    function TextScore(const AQuery, AContent, ASummary: string): Double;
  public
    constructor Create(AStorage: TC4DWizardMemoryStorage;
      AVectorizer: TC4DWizardMemoryVectorizer);

    /// <summary>
    /// Returns up to ALimit entries ranked by relevance to AQuery.
    /// AProjectFilter: when non-empty, only entries from that project are included.
    /// </summary>
    function Search(const AQuery: string;
      ALimit: Integer = 5;
      const AProjectFilter: string = '';
      ATypeFilter: TMemoryType = mtConversation;
      AUseTypeFilter: Boolean = False): TArray<TMemorySearchResult>;
  end;

implementation

{ TC4DWizardMemorySearch }

constructor TC4DWizardMemorySearch.Create(AStorage: TC4DWizardMemoryStorage;
  AVectorizer: TC4DWizardMemoryVectorizer);
begin
  FStorage    := AStorage;
  FVectorizer := AVectorizer;
end;

function TC4DWizardMemorySearch.TextScore(const AQuery, AContent,
  ASummary: string): Double;
var
  LWords   : TArray<string>;
  LWord    : string;
  LContent : string;
  LMatches : Integer;
begin
  // Simple word-overlap score: matching_words / total_query_words
  LContent := (AContent + ' ' + ASummary).ToLower;
  LWords   := AQuery.ToLower.Split([' ', ',', '.', ':', ';', '!', '?'],
    TStringSplitOptions.ExcludeEmpty);
  if Length(LWords) = 0 then Exit(0);
  LMatches := 0;
  for LWord in LWords do
    if LContent.Contains(LWord) then
      Inc(LMatches);
  Result := LMatches / Length(LWords);
end;

function TC4DWizardMemorySearch.Search(const AQuery: string;
  ALimit: Integer;
  const AProjectFilter: string;
  ATypeFilter: TMemoryType;
  AUseTypeFilter: Boolean): TArray<TMemorySearchResult>;
var
  LAll     : TArray<TMemoryEntry>;
  LResults : TList<TMemorySearchResult>;
  LEntry   : TMemoryEntry;
  LResult  : TMemorySearchResult;
  LQEmb    : TArray<Double>;
  LVecScore: Double;
  LTxtScore: Double;
  LFinalScore: Double;
  LHasVec  : Boolean;
begin
  LAll     := FStorage.AllMemories;
  LResults := TList<TMemorySearchResult>.Create;

  // Get query embedding once (may be empty if Ollama offline)
  LQEmb := nil;
  if Assigned(FVectorizer) and FVectorizer.Enabled then
    LQEmb := FVectorizer.GetEmbedding(AQuery);
  LHasVec := Length(LQEmb) > 0;

  try
    for LEntry in LAll do
    begin
      // Apply project filter
      if (not AProjectFilter.IsEmpty) and
         (not LEntry.ProjectPath.IsEmpty) and
         (LEntry.ProjectPath <> AProjectFilter) then
        Continue;

      // Apply type filter
      if AUseTypeFilter and (LEntry.Type_ <> ATypeFilter) then
        Continue;

      LTxtScore := TextScore(AQuery, LEntry.Content, LEntry.Summary);

      if LHasVec and (Length(LEntry.Embedding) > 0) then
      begin
        LVecScore := TC4DWizardMemoryVectorizer.CosineSimilarity(LQEmb, LEntry.Embedding);
        LFinalScore := 0.6 * LVecScore + 0.4 * LTxtScore;
      end
      else
        LFinalScore := LTxtScore;

      if LFinalScore > 0.05 then  // noise floor
      begin
        LResult.Entry := LEntry;
        LResult.Score := LFinalScore;
        LResults.Add(LResult);
      end;
    end;

    // Sort descending
    LResults.Sort(TComparer<TMemorySearchResult>.Construct(
      function(const A, B: TMemorySearchResult): Integer
      begin
        if A.Score > B.Score then Result := -1
        else if A.Score < B.Score then Result := 1
        else Result := 0;
      end));

    if LResults.Count > ALimit then
      LResults.Count := ALimit;

    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

end.
