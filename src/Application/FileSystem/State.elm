module FileSystem.State exposing (..)

import Browser.Dom as Dom
import Common
import Common.State as Common
import Debouncing
import Drive.Item
import Drive.Sidebar as Sidebar
import FileSystem
import Json.Decode as Json
import List.Extra as List
import Maybe.Extra as Maybe
import Ports
import Radix exposing (..)
import Return exposing (return)
import Return.Extra as Return
import Routing
import Task



-- 🐚


{-| TODO This function is doing a lot. Can we break it up somehow?
-}
gotDirectoryList : Json.Value -> Manager
gotDirectoryList json model =
    let
        pathSegments =
            json
                |> Json.decodeValue
                    (Json.field "pathSegments" <| Json.list Json.string)
                |> Result.withDefault
                    []

        encodedDirList =
            json
                |> Json.decodeValue
                    (Json.field "results" Json.value)
                |> Result.withDefault
                    json

        maybeRootCid =
            json
                |> Json.decodeValue (Json.field "rootCid" Json.string)
                |> Result.toMaybe
                |> Maybe.orElse model.fileSystemCid
    in
    encodedDirList
        |> Json.decodeValue (Json.list FileSystem.itemDecoder)
        |> Result.map (List.map Drive.Item.fromFileSystem)
        |> Result.mapError Json.errorToString
        |> (\result ->
                let
                    floor =
                        List.length pathSegments + 1

                    listResult =
                        Result.map
                            ({ isGroundFloor = floor == 1 }
                                |> Drive.Item.sortingFunction
                                |> List.sortWith
                            )
                            result

                    lastRouteSegment =
                        List.last (Routing.treePathSegments model.route)

                    selectedPath =
                        case listResult of
                            Ok [ singleItem ] ->
                                if Just singleItem.name == lastRouteSegment then
                                    Just singleItem.path

                                else
                                    Nothing

                            _ ->
                                Nothing

                    sidebar =
                        case model.sidebar of
                            Just sidebarModel ->
                                case sidebarModel of
                                    Sidebar.EditPlaintext editPlaintext ->
                                        case editPlaintext.editor of
                                            Just editorModel ->
                                                let
                                                    editPath =
                                                        editPlaintext.path
                                                            |> String.split "/"

                                                    editDirectoryWithPrivate =
                                                        editPath
                                                            |> List.take (List.length editPath - 1)

                                                    editDirectory =
                                                        case editDirectoryWithPrivate of
                                                            first :: rest ->
                                                                if first == "private" then
                                                                    rest

                                                                else
                                                                    first :: rest

                                                            other ->
                                                                other
                                                in
                                                if pathSegments == editDirectory then
                                                    { editorModel
                                                        | isSaving = False
                                                        , originalText = editorModel.text
                                                    }
                                                        |> Just
                                                        |> (\newEditor -> { editPlaintext | editor = newEditor })
                                                        |> Sidebar.EditPlaintext
                                                        |> Just

                                                else
                                                    Nothing

                                            _ ->
                                                Nothing

                                    _ ->
                                        Nothing

                            _ ->
                                Nothing
                in
                { model
                    | directoryList =
                        Result.map
                            (\items -> { floor = floor, items = items })
                            listResult

                    --
                    , sidebar =
                        sidebar
                            |> Maybe.orElse
                                (selectedPath
                                    |> Maybe.map Sidebar.details
                                )
                    , fileSystemCid = maybeRootCid
                    , fileSystemStatus = FileSystem.Ready
                    , selectedPath = selectedPath
                    , showLoadingOverlay = False
                }
           )
        |> Return.singleton
        |> Return.andThen Debouncing.cancelLoading
        |> Return.command
            (Task.attempt
                (always Bypass)
                (Dom.setViewport 0 0)
            )


gotItemUtf8 : { pathSegments : List String, text : String } -> Manager
gotItemUtf8 { pathSegments, text } model =
    (case model.sidebar of
        Just sidebar ->
            case sidebar of
                Sidebar.EditPlaintext editPlaintext ->
                    { text = text
                    , originalText = text
                    , isSaving = False
                    }
                        |> Just
                        |> (\newEditor -> { editPlaintext | editor = newEditor })
                        |> Sidebar.EditPlaintext
                        |> Just
                        |> (\newSidebar -> { model | sidebar = newSidebar })

                _ ->
                    model

        _ ->
            model
    )
        |> Return.singleton


gotError : String -> Manager
gotError error model =
    Return.singleton
        { model
            | fileSystemCid = Nothing
            , fileSystemStatus = FileSystem.Error error
        }
