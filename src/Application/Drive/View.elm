module Drive.View exposing (view)

import Common
import Common.View as Common
import Common.View.Footer as Footer
import Drive.Types as Drive
import Explore.View as Explore
import FeatherIcons
import Html exposing (Html)
import Html.Attributes as A
import Html.Events as E
import Html.Extra as Html exposing (nothing)
import Html.Lazy
import Ipfs
import Item exposing (Item, Kind(..))
import List.Extra as List
import Maybe.Extra as Maybe
import Routing exposing (Page(..))
import Styling as S
import Tailwind as T
import Time
import Time.Distance
import Types exposing (..)
import Url.Builder



-- 🖼


view : Model -> Html Msg
view model =
    Html.div
        [ T.flex
        , T.flex_col
        , T.h_screen
        ]
        [ header model
        , content model
        , Footer.view model
        ]



-- HEADER


header : Model -> Html Msg
header model =
    let
        segments =
            Routing.drivePathSegments model.page

        amountOfSegments =
            List.length segments
    in
    Html.header
        [ T.bg_gray_600
        , T.break_all
        , T.py_8
        , T.text_white

        -- Dark mode
        ------------
        , T.dark__bg_gray_100
        ]
        [ Html.div
            [ T.container
            , S.container_padding
            , T.flex
            , T.items_center
            , T.mb_px
            , T.mx_auto
            , T.pb_1
            ]
            [ -----------------------------------------
              -- Icon
              -----------------------------------------
              FeatherIcons.hardDrive
                |> FeatherIcons.withSize S.iconSize
                |> FeatherIcons.toHtml []
                |> List.singleton
                |> Html.div
                    [ T.mr_5
                    , T.opacity_50
                    , T.text_purple
                    ]

            -----------------------------------------
            -- Path
            -----------------------------------------
            -- Tablet and bigger screens
            , segments
                |> List.reverse
                |> List.indexedMap
                    (\idx ->
                        if idx == 0 then
                            activePathPart

                        else
                            inactivePathPart (amountOfSegments - idx + 1)
                    )
                |> List.reverse
                |> List.append
                    [ rootPathPart model segments
                    ]
                |> List.intersperse pathSeparator
                |> Html.div
                    [ T.flex_auto
                    , T.hidden
                    , T.italic
                    , T.leading_snug
                    , T.text_2xl
                    , T.tracking_tight

                    --
                    , T.md__block
                    ]

            -- Mobile
            , segments
                |> List.append [ "ROOT" ]
                |> List.reverse
                |> List.indexedMap
                    (\idx segment ->
                        if idx == 0 && amountOfSegments == 0 then
                            Just <| rootPathPart model segments

                        else if idx == 0 then
                            Just <| activePathPart segment

                        else if idx == 1 then
                            Just <| inactivePathPart (amountOfSegments - idx + 1) "…"

                        else
                            Nothing
                    )
                |> List.filterMap identity
                |> List.reverse
                |> List.intersperse pathSeparator
                |> Html.div
                    [ T.flex_auto
                    , T.italic
                    , T.leading_snug
                    , T.text_2xl
                    , T.tracking_tight

                    --
                    , T.md__hidden
                    ]

            -----------------------------------------
            -- Actions
            -----------------------------------------
            , Html.div
                [ T.hidden
                , T.items_center
                , T.ml_4

                --
                , T.lg__flex
                ]
                [ Html.div
                    [ T.border_2
                    , T.border_gray_500
                    , T.cursor_not_allowed
                    , T.pl_8
                    , T.pr_3
                    , T.py_1
                    , T.relative
                    , T.rounded_full
                    , T.text_gray_500
                    , T.w_48

                    -- Dark mode
                    ------------
                    , T.dark__border_gray_200
                    , T.dark__text_gray_200
                    ]
                    [ FeatherIcons.search
                        |> FeatherIcons.withSize 20
                        |> FeatherIcons.toHtml []
                        |> List.singleton
                        |> Html.span
                            [ T.absolute
                            , T.left_0
                            , T.ml_2
                            , T.neg_translate_y_1over2
                            , T.text_gray_500
                            , T.top_1over2
                            , T.transform

                            -- Dark mode
                            ------------
                            , T.dark__text_gray_200
                            ]

                    --
                    , Html.text "Search"
                    ]
                ]
            ]
        ]


inactivePathPart : Int -> String -> Html Msg
inactivePathPart idx text =
    Html.span
        [ A.class "underline-thick"

        --
        , { floor = idx }
            |> Drive.GoUp
            |> DriveMsg
            |> E.onClick

        --
        , T.cursor_pointer
        , T.pb_px
        , T.tdc_gray_500
        , T.text_gray_300
        , T.underline

        -- Dark mode
        ------------
        , T.dark__tdc_gray_200
        , T.dark__text_gray_400
        ]
        [ Html.text text ]


activePathPart : String -> Html Msg
activePathPart text =
    Html.span
        [ T.text_purple ]
        [ Html.text text ]


pathSeparator : Html Msg
pathSeparator =
    Html.span
        [ T.antialiased
        , T.mx_3
        , T.text_gray_500

        -- Dark mode
        ------------
        , T.dark__text_gray_200
        ]
        [ Html.text "/" ]


rootPathPart : Model -> List String -> Html Msg
rootPathPart model segments =
    let
        rootCid =
            Maybe.withDefault "" model.rootCid

        text =
            String.dropLeft (String.length rootCid - 12) rootCid

        attributes =
            case segments of
                [] ->
                    [ T.pb_px
                    , T.text_purple
                    ]

                _ ->
                    [ A.class "underline-thick"

                    --
                    , { floor = 0 }
                        |> Drive.GoUp
                        |> DriveMsg
                        |> E.onClick

                    --
                    , T.cursor_pointer
                    , T.pb_px
                    , T.tdc_gray_500
                    , T.text_gray_300
                    , T.underline

                    -- Dark mode
                    ------------
                    , T.dark__tdc_gray_200
                    , T.dark__text_gray_400
                    ]
    in
    Html.span
        (Common.fadeOutLeft :: attributes)
        [ Html.text text ]



-- MAIN


content : Model -> Html Msg
content model =
    case model.directoryList of
        Ok [] ->
            empty

        Ok directoryList ->
            contentAvailable model directoryList

        Err err ->
            -- Error is handled by the root view,
            -- which will render the explore view.
            empty


empty : Html Msg
empty =
    Html.div
        [ T.flex
        , T.flex_auto
        , T.flex_col
        , T.items_center
        , T.justify_center
        , T.leading_snug
        , T.text_center
        ]
        [ FeatherIcons.folder
            |> FeatherIcons.withSize 88
            |> FeatherIcons.toHtml []
            |> List.singleton
            |> Html.div [ T.opacity_50 ]

        --
        , Html.div
            [ T.mt_4, T.text_lg ]
            [ Html.text "Nothing to see here,"
            , Html.br [] []
            , Html.text "empty directory"
            ]
        ]


contentAvailable : Model -> List Item -> Html Msg
contentAvailable model directoryList =
    Html.div
        [ T.flex
        , T.flex_auto
        , T.overflow_hidden
        ]
        [ Html.div
            [ T.container
            , S.container_padding
            , T.flex
            , T.flex_auto
            , T.items_stretch
            , T.mx_auto
            , T.my_8
            ]
            [ Html.div
                (List.append
                    [ A.id "drive-items"

                    --
                    , T.flex_auto
                    , T.overflow_x_hidden
                    , T.overflow_y_scroll
                    , T.w_1over2
                    ]
                    (if model.largePreview then
                        [ T.hidden ]

                     else if Maybe.isJust model.selectedCid then
                        [ T.hidden, T.md__block, T.pr_12, T.lg__pr_24 ]

                     else
                        []
                    )
                )
                [ list model directoryList
                ]

            --
            , model.selectedCid
                |> Maybe.andThen (\cid -> List.find (.path >> (==) cid) directoryList)
                |> Maybe.map
                    (Html.Lazy.lazy5
                        details
                        model.currentTime
                        (Common.directoryPath model)
                        model.largePreview
                        model.showPreviewOverlay
                    )
                |> Maybe.withDefault nothing
            ]
        ]



-- MAIN  /  LIST


list : Model -> List Item -> Html Msg
list model directoryList =
    Html.div
        [ T.text_lg ]
        [ Html.div
            [ T.antialiased
            , T.font_semibold
            , T.mb_1
            , T.text_gray_400
            , T.text_xs
            , T.tracking_wider

            -- Dark mode
            ------------
            , T.dark__text_gray_300
            ]
            [ Html.text "NAME" ]

        -----------------------------------------
        -- Tree
        -----------------------------------------
        , directoryList
            |> List.sortWith sortingFunction
            |> List.map (listItem model.selectedCid)
            |> Html.div []

        -----------------------------------------
        -- Stats
        -----------------------------------------
        , let
            ( amountOfDirs, amountOfFiles, size ) =
                List.foldl
                    (\i ( d, f, s ) ->
                        if i.kind == Directory then
                            ( d + 1, f, s + i.size )

                        else
                            ( d, f + 1, s + i.size )
                    )
                    ( 0, 0, 0 )
                    directoryList

            sizeString =
                Common.sizeInWords size
          in
          Html.div
            [ T.mt_8
            , T.text_gray_400
            , T.text_sm

            -- Dark mode
            ------------
            , T.dark__text_gray_300
            ]
            [ case amountOfDirs of
                0 ->
                    nothing

                1 ->
                    Html.text (String.fromInt amountOfDirs ++ " Directory")

                _ ->
                    Html.text (String.fromInt amountOfDirs ++ " Directories")

            --
            , Html.viewIf
                (amountOfDirs > 0 && amountOfFiles > 0)
                (Html.text " and ")

            --
            , case amountOfFiles of
                0 ->
                    nothing

                1 ->
                    Html.text (String.fromInt amountOfFiles ++ " File (" ++ sizeString ++ ")")

                _ ->
                    Html.text (String.fromInt amountOfFiles ++ " Files (" ++ sizeString ++ ")")
            ]
        ]


listItem : Maybe String -> Item -> Html Msg
listItem selectedCid ({ kind, loading, name, nameProperties, path } as item) =
    let
        selected =
            selectedCid == Just path
    in
    Html.div
        [ case kind of
            Directory ->
                { directoryName = name }
                    |> Drive.DigDeeper
                    |> DriveMsg
                    |> E.onClick

            _ ->
                item
                    |> Drive.Select
                    |> DriveMsg
                    |> E.onClick

        --
        , T.border_b
        , T.border_gray_700
        , T.cursor_pointer
        , T.flex
        , T.items_center
        , T.mt_px
        , T.py_4

        --
        , if selected then
            T.text_purple

          else
            T.text_inherit

        -- Dark mode
        ------------
        , T.dark__border_darkness_above

        --
        , if selected then
            T.dark__text_white

          else
            T.dark__text_inherit
        ]
        [ -----------------------------------------
          -- Icon
          -----------------------------------------
          kind
            |> Item.kindIcon
            |> FeatherIcons.withSize S.iconSize
            |> FeatherIcons.toHtml []
            |> List.singleton
            |> Html.div [ T.flex_shrink_0 ]

        -----------------------------------------
        -- Label & Extensions
        -----------------------------------------
        , Html.span
            [ T.flex_auto, T.ml_5, T.truncate ]
            [ Html.text nameProperties.base

            --
            , case nameProperties.extension of
                "" ->
                    nothing

                ext ->
                    Html.span
                        [ T.antialiased
                        , T.bg_gray_600
                        , T.font_semibold
                        , T.leading_loose
                        , T.ml_2
                        , T.px_1
                        , T.py_px
                        , T.rounded
                        , T.text_gray_200
                        , T.text_xs
                        , T.uppercase

                        -- Dark mode
                        ------------
                        , T.dark__bg_gray_200
                        , T.dark__text_gray_500
                        ]
                        [ Html.text ext ]
            ]

        --
        , if loading then
            FeatherIcons.loader
                |> FeatherIcons.withSize S.iconSize
                |> FeatherIcons.toHtml []
                |> List.singleton
                |> Html.span [ T.animation_spin, T.ml_2 ]

          else
            nothing

        --
        , if selected then
            FeatherIcons.arrowRight
                |> FeatherIcons.withSize S.iconSize
                |> FeatherIcons.toHtml []
                |> List.singleton
                |> Html.span [ T.ml_2, T.opacity_50 ]

          else
            nothing
        ]



-- MAIN  /  DETAILS


details : Time.Posix -> String -> Bool -> Bool -> Item -> Html Msg
details currentTime parentPath largePreview showPreviewOverlay item =
    Html.div
        [ T.bg_gray_900
        , T.flex
        , T.flex_auto
        , T.flex_col
        , T.group
        , T.items_center
        , T.justify_center
        , T.overflow_hidden
        , T.px_4
        , T.py_6
        , T.relative
        , T.rounded_md
        , T.w_1over2

        -- Dark mode
        ------------
        , T.dark__bg_darkness_below
        ]
        [ detailsOverlay currentTime parentPath largePreview showPreviewOverlay item
        , detailsDataContainer item
        , detailsExtra item
        ]


detailsDataContainer : Item -> Html Msg
detailsDataContainer item =
    let
        defaultStyles =
            [ T.absolute
            , T.flex
            , T.inset_0
            , T.items_center
            , T.justify_center
            , T.z_10
            ]
    in
    Html.div
        (List.append
            [ A.id item.id
            , A.class "drive-item__preview"
            ]
            (case item.kind of
                Item.Audio ->
                    [ T.mt_8
                    ]

                Item.Image ->
                    List.append
                        defaultStyles
                        [ E.onClick (DriveMsg Drive.ShowPreviewOverlay)
                        , T.cursor_pointer
                        ]

                _ ->
                    defaultStyles
            )
        )
        [ case item.kind of
            Item.Image ->
                Html.nothing

            _ ->
                Common.loadingAnimation
        ]


detailsOverlay : Time.Posix -> String -> Bool -> Bool -> Item -> Html Msg
detailsOverlay currentTime parentPath largePreview showPreviewOverlay item =
    let
        defaultAttributes =
            [ T.absolute
            , S.default_transition_duration
            , S.default_transition_easing
            , T.flex
            , T.flex_col
            , T.inset_0
            , T.items_center
            , T.justify_center
            , T.px_4
            , T.transition_opacity
            , T.z_20
            ]
    in
    Html.div
        (case item.kind of
            Item.Audio ->
                []

            Item.Video ->
                [ T.hidden ]

            Item.Image ->
                List.append
                    defaultAttributes
                    (if showPreviewOverlay then
                        []

                     else
                        [ T.opacity_0
                        , T.pointer_events_none
                        , T.group_hover__opacity_100
                        , T.group_hover__pointer_events_auto
                        ]
                    )

            _ ->
                defaultAttributes
        )
        [ Html.div
            [ T.relative
            , T.z_10
            ]
            (detailsOverlayContents currentTime parentPath item)

        --
        , Html.div
            [ T.absolute
            , T.bg_gray_900
            , T.inset_0
            , T.z_0

            --
            , case item.kind of
                Item.Image ->
                    T.opacity_80

                _ ->
                    T.opacity_100

            -- Dark mode
            ------------
            , T.dark__bg_darkness_below
            ]
            []

        --
        , detailsActions largePreview
        ]


detailsOverlayContents : Time.Posix -> String -> Item -> List (Html Msg)
detailsOverlayContents currentTime parentPath item =
    [ item.kind
        |> Item.kindIcon
        |> FeatherIcons.withSize 128
        |> FeatherIcons.withStrokeWidth 0.5
        |> FeatherIcons.toHtml []
        |> List.singleton
        |> Html.div
            [ T.flex
            , T.flex_col
            , T.items_center
            ]

    --
    , Html.div
        [ T.font_semibold
        , T.mt_1
        , T.text_center
        , T.tracking_tight
        , T.truncate
        ]
        [ Html.text item.name ]

    --
    , Html.div
        [ T.mt_px
        , T.text_center
        , T.text_gray_300
        , T.text_sm
        ]
        [ -- TODO
          item.posixTime
            |> Maybe.map (Time.Distance.inWords currentTime)
            |> Maybe.unwrap (Html.text <| Common.sizeInWords item.size) Html.text
        ]

    --
    , Html.div
        [ T.flex
        , T.items_center
        , T.justify_center
        , T.mt_5
        ]
        [ Html.a
            [ A.href (Item.publicUrl parentPath item)
            , A.target "_blank"

            --
            , T.antialiased
            , T.bg_purple
            , T.font_semibold
            , T.inline_block
            , T.px_2
            , T.py_1
            , T.rounded
            , T.text_gray_900
            , T.text_sm
            , T.tracking_wider
            , T.uppercase
            ]
            [ Html.span
                [ T.block, T.pt_px ]
                [ Html.text "Open in new tab" ]
            ]

        --
        , Html.button
            [ E.onClick (DriveMsg <| Drive.CopyLink item)

            --
            , T.appearance_none
            , T.ml_3
            , T.text_purple
            ]
            [ FeatherIcons.share
                |> FeatherIcons.withSize 18
                |> FeatherIcons.toHtml []
            ]
        ]
    ]


detailsExtra : Item -> Html Msg
detailsExtra item =
    Html.div
        [ T.relative
        , T.z_0
        ]
        [ case item.kind of
            Item.Image ->
                Common.loadingAnimation

            _ ->
                Html.nothing
        ]


detailsActions : Bool -> Html Msg
detailsActions largePreview =
    Html.div
        [ T.absolute
        , T.bg_gray_400
        , T.border_b
        , T.border_t_2
        , T.border_transparent
        , T.flex
        , T.items_center
        , T.right_0
        , T.rounded_bl
        , T.text_gray_900
        , T.top_0
        , T.z_30

        -- Dark mode
        ------------
        , T.dark__bg_darkness_above
        , T.dark__text_gray_300
        ]
        [ (if largePreview then
            FeatherIcons.minimize2

           else
            FeatherIcons.maximize2
          )
            |> FeatherIcons.withSize 16
            |> FeatherIcons.toHtml [ A.style "margin" "0 auto" ]
            |> List.singleton
            |> Html.div
                [ E.onClick (DriveMsg Drive.ToggleLargePreview)

                --
                , T.box_content
                , T.cursor_pointer
                , T.hidden
                , T.px_3
                , T.py_2
                , T.w_6

                --
                , T.md__block
                ]

        --
        , Html.span
            [ T.border_gray_500
            , T.border_l
            , T.hidden
            , T.opacity_50
            , T.self_stretch
            , T.w_0

            --
            , T.md__block

            -- Dark mode
            ------------
            , T.dark__border_gray_200
            ]
            []

        --
        , FeatherIcons.x
            |> FeatherIcons.withSize 20
            |> FeatherIcons.toHtml [ A.style "margin" "0 auto" ]
            |> List.singleton
            |> Html.div
                [ E.onClick (DriveMsg Drive.RemoveSelection)

                --
                , T.box_content
                , T.cursor_pointer
                , T.px_3
                , T.py_2
                , T.w_6
                ]
        ]



-- 🛠


sortingFunction : Item -> Item -> Order
sortingFunction a b =
    -- Put directories on top,
    -- and then sort alphabetically by name
    case ( a.kind, b.kind ) of
        ( Directory, Directory ) ->
            compare (String.toLower a.name) (String.toLower b.name)

        ( Directory, _ ) ->
            LT

        ( _, Directory ) ->
            GT

        ( _, _ ) ->
            compare (String.toLower a.name) (String.toLower b.name)
