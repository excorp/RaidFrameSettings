local L = LibStub("AceLocale-3.0"):NewLocale("RaidFrameSettings_Fork", "koKR")
if not L then return end

L["Raid Frame Settings"] = "레이드 프레임 셋팅"
L["Enabled Modules"]     = "모듈 활성화"
L["Module Settings"]     = "모듈 설정"

L["Modules"]             = "모듈"
L["Health Bars"]         = "체력바"
L["Fonts"]               = "글꼴"
L["Role Icon"]           = "역활 아이콘"
L["Raid Mark"]           = "징표"
L["Range"]               = "거리"
L["Aura Filter"]         = "오라 필터"
L["Auras"]               = "오라(버프/디버프)"
L["Auras:"]              = "오라:"
L["Buffs"]               = "버프"
L["Debuffs"]             = "디버프"
L["Overabsorb"]          = "초과흡수"
L["Aura Highlight"]      = "오라 하이라이트"
L["Custom Scale"]        = "커스텀 스케일"
L["Solo"]                = "솔로"
L["Profiles"]            = "프로필"


L["Choose colors and textures for Health Bars.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |cffFFFF00MEDIUM|r"] = "체력바의 색상과 텍스처를 선택합니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r ~ |cffFFFF00중간|r"
L["Adjust the Font, Font Size, Font Color as well as the position for the Names and Status Texts.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |cffFFFF00MEDIUM|r"] = "글꼴, 크기, 색상은 물론 이름과 상태 텍스트의 위치를 조정할 수 있습니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r ~ |cffFFFF00중간|r"
L["Position the Role Icon.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r"] = "역할 아이콘을 재배치합니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r"
L["Position the Raid Mark.\n|cffF4A460CPU Impact: |r|cff90EE90VERY LOW|r"] = "징표를 재배치합니다..\n|cffF4A460CPU 영향: |r|cff90EE90매우 낮음|r"
L["Use custom alpha values for out of range units.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |r|cffFFFF00MEDIUM|r"] = "멀리있는 유닛의 알파값을 설정합니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r ~ |r|cffFFFF00중간|r"
L["Sets the visibility, hiding, and priority of the aura.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r"] = "오라의 표시 여부, 숨김 및 우선 순위를 설정합니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r"
L["Adjust the position, orientation and size of buffs.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |r|cffFFFF00MEDIUM|r"] = "버프의 위치, 방향, 크기를 조정합니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r ~ |r|cffFFFF00중간|r"
L["Adjust the position, orientation and size of debuffs.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |r|cffFFFF00MEDIUM|r"] = "디버프의 위치, 방향, 크기를 조정합니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r ~ |r|cffFFFF00중간|r"
L["Show absorbs above the units max hp.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r"] = "보호막이 최대 체력 이상일때의 표시기를 설정합니다.\n|cffF4A460CPU 영향: |r|cff00ff00낮음|r"
L["Recolor unit health bars based on debuff type.\n|cffF4A460CPU Impact: |r|cffFFFF00MEDIUM|r to |r|cffFF474DHIGH|r"] = "디버프 유형에 따라 유닛 체력바의 색상을 변경합니다.\n|cffF4A460CPU 영향: |r|cffFFFF00중간|r ~ |r|cffFF474D높음|r"
L["Set a scaling factor for raid and party frames.\n|cffF4A460CPU Impact: |r|cff90EE90NEGLIGIBLE|r"] = "레이드 및 파티 프레임의 스케일링 계수를 설정합니다.\n|cffF4A460CPU 영향: |r|cff90EE90없음|r"
L["Use CompactParty when Solo.\n|cffF4A460CPU Impact: |r|cff90EE90VERY LOW|r"] = "파티중이 아닐때에도 레이드 프레임을 표시 합니다.\n|cffF4A460CPU 영향: |r|cff90EE90매우 낮음|r"


L["Hints:"] = "참고:"
L["The default UI links the name text to the right of the role icon, so in some cases you will need to use both modules if you want to use either one."] = "기본 UI에서는 역할 아이콘 오른쪽에 이름 텍스트가 연결되어 있으므로 글꼴과 역활 아이콘중 하나의 모듈만 사용하고 싶어도 둘다 사용해야 하는 경우도 있습니다."
L["About |cffF4A460CPU Impact:|r The first value means small 5 man groups, the last value massive 40 man raids. As more frames are added, the addon must do more work. The addon runs very efficiently when the frames are set up, but you can get spikes when people spam leave and/or join the group, such as at the end of a battleground or in massive open world farm groups. The blizzard frames update very often in these scenarios and the addon needs to follow this."] =
"|cffF4A460CPU 영향:|r 앞의 값은 5인 파티, 뒤의 값은 40인 레이드에서 영향을 의미합니다. 더 많은 프레임이 추가되면 애드온이 더 많은 작업을 수행해야 합니다. 애드온은 프레임이 설정되어 있을 때는 매우 효율적으로 실행되지만, 전장이 끝날 때나 필드 보스 레이드, 레이드와 같이 사람들이 대량으로 파티에서 떠나거나 합류할 때 급격히 증가할 수 있습니다. 이러한 상황에서는 블리자드 프레임이 매우 자주 업데이트되므로 애드온이 이를 따라야 합니다."


L["Position"]                            = "위치"
L["x - offset"]                          = "X 오프셋"
L["y - offset"]                          = "Y 오프셋"
L["scale"]                               = "스케일"
L["Anchor"]                              = "고정위치"
L["to Frames"]                           = "부착위치"
L["to Attach Frame"]                     = "부착할 프레임"
L["width"]                               = "가로"
L["height"]                              = "세로"
L["alpha"]                               = "투명도"
L["Range Alpha"]                         = "거래 투명도"
L["Foreground"]                          = "전경색"
L["Background"]                          = "배경색"
L["Party"]                               = "파티"
L["Arena"]                               = "투기장"
L["Raid"]                                = "레이드"
L["Glow intensity"]                      = "표시기 투명도"
L["Glow position"]                       = "표시기 위치"
L["TimerText Format Limit (by seconds)"] = "남은 시간 표시 형식 기준치 (단위:초)"
L["Second Limit"]                        = "초단위 표시 기준"
L["Minute Limit"]                        = "분단위 표시 기준"
L["Hour Limit"]                          = "시간단위 표시 기준"
L["Raid/Party Profile"]                  = "레이드/파티 프로필"
L["Battleground"]                        = "전장"


L["The profiles you select above will be loaded based on the type of group you are in, if you want to use the same profile for all cases select it for all cases."] = "위에서 선택한 프로필은 소속된 그룹 유형에 따라 로드되며, 모든 케이스에 동일한 프로필을 사용하려면 모든 케이스에 대해 선택합니다."
L["Import/Export Profile"] = "프로필 가져오기/내보내기"
L["Share your profile or import one"] = "프로필 공유 또는 프로필 가져오기"
L["To export your current profile copy the code below.\nTo import a profile replace the code below and press Accept"] = "현재 프로필을 내보내려면 아래 코드를 복사합니다.\n프로필을 가져오려면 아래 코드를 바꾸고 수락을 누릅니다."
L["import/export from or to your current profile"] = "현재 프로필에서 또는 현재 프로필로 가져오기/내보내기"


-- fonts
L["Name"]                       = "이름"
L["Status"]                     = "상태"
L["Advanced"]                   = "추가설정"
L["Align"]                      = "정렬"
L["Border"]                     = "테두리"

L["Colors"]                     = "색상"
L["Textures"]                   = "텍스쳐"

L["Font"]                       = "폰트"
L["Font Color"]                 = "폰트 색상"
L["Font Size"]                  = "폰트 크기"

L["Outlinemode"]                = "외곽선 모드"
L["OUTLINE"]                    = "외곽선"
L["THICK"]                      = "굵게"
L["MONOCHROME"]                 = "모노크롬"

L["Class Colored"]              = "직업 색상"
L["Name color"]                 = "이름 색상"
L["Status color"]               = "상태 색상"
L["Shadow Color"]               = "그림자 색상"
L["Shadow x-offset"]            = "그림자 X 오프셋"
L["Shadow y-offset"]            = "그림자 Y 오프셋"

-- health bar
L["Color HealthBar"]            = "체력바 색 사용"
L["Health Bar Background"]      = "체력바 배경색"
L["Health Bar"]                 = "체력바"
L["Power Bar"]                  = "자원바"
L["Glow HealthBar"]             = "체력바 반짝임"

-- aruas
L["Display"]                    = "표시"
L["Duration"]                   = "지속시간"
L["Stacks"]                     = "중첩수"
L["Aura Increase"]              = "오라 강조(크게)"
L["Aura Position"]              = "고정 위치 오라"
L["Auto Max buffes"]            = "표시 버프수 자동조정"
L["Max buffes"]                 = "최대 표시 버프수"
L["Max Debuffes"]               = "최대 표시 디버프수"

L["Buff Frames"]                = "버프 프레임"
L["Buffframe anchor"]           = "버프 고정위치"

L["Debuff Frames"]              = "디버프 프레임"
L["Debuffframe anchor"]         = "디버프 고정위치"
L["Debuff Colored"]             = "디버프 색상 사용"

L["Clean Icons"]                = "깨끗한 아이콘"
L["Frame Strata"]               = "Frame Strata"
L["Show \"Edge\""]              = "Edge 표시"
L["Show \"Swipe\""]             = "Swipe 사용"
L["Inverse"]                    = "Swipe 반대로"
L["Show Duration Timer Text"]   = "지속시간 표시"

L["Gap"]                        = "간격"
L["Directions for growth"]      = "성장방향"
L["Baseline"]                   = "기준선"

L["FrameNo"]                    = "프레임번호"
L["Frame Select"]               = "프레임 선택"
L["Frame No"]                   = "프레임 번호"
L["Set Size"]                   = "크기 설정"
L["Icon Width"]                 = "아이콘 가로크기"
L["Icon Height"]                = "아이콘 세로크기"

L["SpellId"]                    = "주문ID"
L["Enter spellIDs"]             = "주문ID를 입력 하세요"
L["Enter spellId:"]             = "주문ID 입력:"
L["Filtered Auras:"]            = "오라 필터:"
L["|cffff0000aura not found|r"] = "|cffff0000주문을 찾을수 없습니다|r"

L["Group "]                     = "그룹 "
L["Order"]                      = "순서"
L["GroupNo"]                    = "그룹번호"
L["Groupname"]                  = "그룹이름"
L["New Group"]                  = "새 오라 그룹"
L["Unlimit Auras"]              = "모든 오라 표시"
L["Max Auras"]                  = "최대 표시 갯수"

-- increase
L["Increase"]                   = "강조(크게)"
L["Increase:"]                  = "강조(크게):"

-- aura filter
L["Show"]                       = "보임"
L["Other's buff"]               = "다른사람의 버프표시"
L["Priority"]                   = "중요도"
L["Hide In Combat"]             = "전투중 숨김"

-- aura highlihgt
L["Config"]                     = "설정"
L["Operation mode"]             = "동작 모드"
L["Debuff colors"]              = "디버프 색상"
L["Curse"]                      = "저주"
L["Disease"]                    = "질병"
L["Magic"]                      = "마법"
L["Poison"]                     = "독"
L["Bleed"]                      = "출혈"

L["Missing Aura"]               = "버프 없음"
L["Missing Aura Color"]         = "버프 없을때 색상"
L["Class:"]                     = "직업:"

-- button
L["remove"]                     = "삭제"
L["reset"]                      = "초기화"


-- desc
L["1. - Blizzards setting for Class Colors. \n2. - Blizzards setting for a unified green color. \n3. - AddOns setting for a customizable unified color."]                                             = "1. - 블리자드 - 직업색상 사용. \n2. - 블리자드 - 초록색 사용. \n3. - 애드온 - 사용자 지정 색상 사용."
L["This will increase the size of the auras added in the \34Increase\34 section."]                                                                                                                    = "이렇게 하면 \34강조(크게)\34 섹션에 추가된 아우라의 크기가 증가합니다."
L["Crop the border. Keep the aspect ratio of icons when width is not equal to height."]                                                                                                               = "테두리를 자릅니다. 너비가 높이와 같지 않은 경우 아이콘의 가로 세로 비율을 유지합니다."
L["Show the swipe radial overlay"]                                                                                                                                                                    = "원형 스와이프 오버레이 표시"
L["Show the glowing edge at the end of the radial overlay"]                                                                                                                                           = "Edge 표시"
L["Invert the direction of the radial overlay"]                                                                                                                                                       = "Swipe 색상 반대로"
L["Show an aura timer"]                                                                                                                                                                               = "오라 지속시간 표시"
L["Set up auras to a big aura like a boss aura."]                                                                                                                                                     = "보스오라 처럼 강조(크게) 표시할 오라를 설정 합니다."
L["This will increase the size of \34Boss Auras\34 and the auras added in the \34Increase\34 section. Boss Auras are auras that the game deems to be more important by default."]                     = "\34보스오라\34와 \34강조(크게)\34 섹션에 추가된 오라의 크기가 증가합니다. 보스오라란 게임에서 기본적으로 더 중요하다고 간주하는 오라를 말합니다."
L["Set up auras to have the same size increase as boss auras."]                                                                                                                                       = "보스오라와 같은 크기로 표시할 오라를 설정 합니다."
L["Smart - The add-on will determine which debuffs you can dispel based on your talents and class, and will only highlight those debuffs. \nManual - You choose which debuff types you want to see."] = "스마트 - 추가 기능이 특성 및 직업에 따라 해제할 수 있는 디버프를 결정하고 해당 디버프만 강조 표시합니다. \n수동 - 표시할 디버프 유형을 선택합니다."
L["to default"]                                                                                                                                                                                       = "기본값으로"
L["enter spellIDs seperated by a semicolon or comma\nExample: 12345; 123; 456;"]                                                                                                                      = "주문ID를 세미콜론 또는 쉼표로 구분하여 입력합니다\n예: 12345; 123; 456;"
L["the foreground alpha level when a target is out of range"]                                                                                                                                         = "타겟이 범위를 벗어났을 때의 전경 투명도 레벨"
L["|cffFF0000Caution|r: Importing a profile will overwrite your current profile."]                                                                                                                    = "|cffFF0000주의|r: 프로필을 가져오면 현재 프로필을 덮어쓰게 됩니다."
L["the background alpha level when a target is out of range"]                                                                                                                                         = "타겟이 범위를 벗어났을 때의 배경 투명도 레벨"

-- usage
L["please enter a number"]                                                                                                                                                                            = "번호를 입력하세요."
L["Display in minutes if second limit is exceeded. (please enter a number)"]                                                                                                                          = "초 단위로 표시할 기준시간(초)을 입력하세요. 여기에 입력된 값을 초과할경우 분 단위로 표시됩니다. (숫자를 입력하세요)"
L["Display in hours if minute limit is exceeded. (please enter a number)"]                                                                                                                            = "분 단위로 표시할 기준시간(초)을 입력하세요. 여기에 입력된 값을 초과할경우 시간 단위로 표시됩니다. (숫자를 입력하세요)"
L["Display in days if hour limit is exceeded. (please enter a number)"]                                                                                                                               = "일 단위로 표시할 기준시간(초)을 입력하세요. (숫자를 입력하세요)"
L["please enter a number (spellId of the aura frame you want to attach.)"]                                                                                                                            = "부착하려는 오라 위치 프레임의 주문ID를 입력하세요. (숫자를 입력하세요)"
L["please enter a number (no of aura group you want to attach.)"]                                                                                                                                     = "부착하려는 오라 그룹의 그룹번호를 입력하세요. (숫자를 입력하세요)"
L["please enter a number (The n th frame of the aura group)"]                                                                                                                                         = "부착하려는 오라 그룹의 프레임중 몇번째에 부착할지 입력하세요. (숫자를 입력하세요)"


-- values
L["AddOn - Static Color"]     = "애드온 - 고정색상"
L["Blizzard - Class Color"]   = "블리자드 - 직업색상"
L["Blizzard - Green Color"]   = "블리자드 - 초록색"

L["Top Left"]                 = "왼쪽 위"
L["Top"]                      = "위"
L["Top Right"]                = "오른쪽 위"
L["Left"]                     = "왼쪽"
L["Center"]                   = "중앙"
L["Right"]                    = "오른쪽"
L["Bottom Left"]              = "왼쪽 아래"
L["Bottom"]                   = "아래"
L["Bottom Right"]             = "오른쪽 아래"
L["Middle"]                   = "가운데"

L["Up"]                       = "위"
L["Down"]                     = "아래"
L["Vertical Center"]          = "수평 중앙"
L["Horizontal Center"]        = "수직 중앙"

L["Inherited"]                = "상속"
L["BACKGROUND"]               = "BACKGROUND"
L["LOW"]                      = "LOW"
L["MEDIUM"]                   = "MEDIUM"
L["HIGH"]                     = "HIGH"
L["DIALOG"]                   = "DIALOG"
L["FULLSCREEN"]               = "FULLSCREEN"
L["FULLSCREEN_DIALOG"]        = "FULLSCREEN_DIALOG"
L["TOOLTIP"]                  = "TOOLTIP"

L["First"]                    = "처음"
L["Last"]                     = "끝"
L["Select"]                   = "선택"

L["Unit Frame"]               = "레이드 프레임"
L["Placed"]                   = "고정 위치 오라"
L["Group"]                    = "오라 그룹"

L["Smart"]                    = "스마트"
L["Manual"]                   = "수동"

L["None"]                     = "없음"
L["Outline"]                  = "외곽선"
L["Thick Outline"]            = "두꺼운 외곽선"
L["Monochrome"]               = "모노크롬"
L["Monochrome Outline"]       = "모노크롬 외곽선"
L["Monochrome Thick Outline"] = "모노크롬 두꺼운 외곽선"

L["Default"]                  = "기본"
L["Move left"]                = "왼쪽으로 이동"
L["Move overflow"]            = "넘친만큼 이동"