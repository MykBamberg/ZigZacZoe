const std = @import("std");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

const Board = struct {
    BoardState: [9]Player = [_]Player{Player.NoPlayer} ** 9,

    const Player = enum(u8) {
        NoPlayer = ' ',
        PlayerX = 'X',
        PlayerO = 'O',
    };

    fn printBoard(self: Board) !void {
        const boardTemplate =
            ("\x1b[96m    1 2 3\x1b[0m\n" ++
            "  ╭─┼─┼─┼─╮\n" ++
            "\x1b[96mA\x1b[0m ┼\x1b[31m R R R \x1b[0m┤\n" ++
            "\x1b[96mB\x1b[0m ┼\x1b[31m R R R \x1b[0m┤\n" ++
            "\x1b[96mC\x1b[0m ┼\x1b[31m R R R \x1b[0m┤\n" ++
            "  ╰─┴─┴─┴─╯\n").*;

        var boardString: [boardTemplate.len]u8 = boardTemplate;

        var fieldIndex: u8 = 0;
        for (boardString, 0..) |char, charIndex| {
            if (char == 'R') {
                boardString[charIndex] = @intFromEnum(self.BoardState[fieldIndex]);
                fieldIndex += 1;
            }
        }

        try stdout.print("{s}\n", .{boardString});
    }

    fn checkForWinner(self: Board) Player {
        const state = self.BoardState;

        // Board layout:
        // 0 1 2
        // 3 4 5
        // 6 7 8

        // Diagonals
        if (state[4] != Player.NoPlayer) {
            if ((state[0] == state[4] and state[4] == state[8]) or
                (state[2] == state[4] and state[4] == state[6]))
            {
                return state[4];
            }
        }

        for (0..3) |i| {
            // Rows
            if (state[i * 3 + 0] == state[i * 3 + 1] and
                state[i * 3 + 1] == state[i * 3 + 2] and
                state[i * 3 + 1] != Player.NoPlayer)
            {
                return state[i * 3 + 1];
            }
            // Columns
            if (state[i + 0] == state[i + 3] and
                state[i + 3] == state[i + 6] and
                state[i + 3] != Player.NoPlayer)
            {
                return state[i + 6];
            }
        }

        return Player.NoPlayer;
    }

    fn checkForDraw(self: Board) bool {
        if (checkForWinner(self) != Player.NoPlayer) return false;
        for (self.BoardState) |field| {
            if (field == Player.NoPlayer) return false;
        }

        return true;
    }

    fn playerToMoveNext(self: Board) Player {
        var xPieces: u8 = 0;
        var oPieces: u8 = 0;

        for (self.BoardState) |piece| {
            if (piece == Player.PlayerX) xPieces += 1;
            if (piece == Player.PlayerO) oPieces += 1;
        }

        return if (xPieces == oPieces) Player.PlayerX else Player.PlayerO;
    }

    const MoveError = error{ Occupied, GameOver };

    fn move(self: *Board, fieldIndex: u8) MoveError!void {
        if (checkForWinner(self.*) != Player.NoPlayer) return MoveError.GameOver;
        if (self.BoardState[fieldIndex] != Player.NoPlayer) return MoveError.Occupied;

        self.BoardState[fieldIndex] = playerToMoveNext(self.*);
    }

    const MinimaxReturn = struct { score: i16, move: u8 };

    fn findBestMoveMinimax(board: Board) MinimaxReturn {
        if (board.checkForDraw()) return MinimaxReturn{ .score = 0, .move = 0 };
        const currentWinner = board.checkForWinner();

        if (currentWinner != Player.NoPlayer) {
            return switch (currentWinner) {
                Player.PlayerX => MinimaxReturn{ .score = @as(i16, 1024), .move = 0 },
                Player.PlayerO => MinimaxReturn{ .score = @as(i16, -1024), .move = 0 },
                Player.NoPlayer => unreachable,
            };
        }

        const currentPlayer = board.playerToMoveNext();
        var returnValues: [9]?MinimaxReturn = [_]?MinimaxReturn{null} ** 9;
        var boardCopy = board;

        // Loop through every move, discard impossible moves
        for (0..9) |i| {
            if (board.BoardState[i] == Player.NoPlayer) {
                boardCopy.BoardState[i] = currentPlayer;
                returnValues[i] = findBestMoveMinimax(boardCopy);
                boardCopy.BoardState[i] = Player.NoPlayer;
            }
        }

        const evalMultiplier: i16 = if (currentPlayer == Player.PlayerX) 1 else -1;

        var bestScore: i16 = -1024;
        var bestReturnIndex: u8 = undefined;

        // Loop through every possible move, select most favorable for current player
        for (returnValues, 0..) |possibleNullValue, i| {
            if (possibleNullValue) |value| {
                if (value.score * evalMultiplier > bestScore) {
                    bestScore = value.score * evalMultiplier;
                    bestReturnIndex = @intCast(i);
                }
            }
        }

        return MinimaxReturn{
            // Reduce score to select the *fastest* winning move
            .score = returnValues[bestReturnIndex].?.score >> 1,
            .move = bestReturnIndex,
        };
    }
};

pub fn main() !void {
    var board: Board = Board{};

    var botPlayer = Board.Player.PlayerO;

    {
        const allocator = std.heap.page_allocator;

        var argsIterator = try std.process.ArgIterator.initWithAllocator(allocator);
        defer argsIterator.deinit();

        const path = argsIterator.next() orelse unreachable;

        if (argsIterator.next()) |arg| {
            if (std.mem.eql(u8, arg, "x")) {
                botPlayer = Board.Player.PlayerX;
            } else if (std.mem.eql(u8, arg, "o")) {
                botPlayer = Board.Player.PlayerO;
            } else if (std.mem.eql(u8, arg, "nobot")) {
                botPlayer = Board.Player.NoPlayer;
            } else {
                try stdout.print(
                    \\Usage:
                    \\{s} nobot - Play regular game of TicTacToe
                    \\{s} x - Play against bot player X
                    \\{s} o - Play against bot player O
                    \\
                , .{path, path, path});
                return;
            }
        }
    }

    while (board.checkForWinner() == Board.Player.NoPlayer and !board.checkForDraw()) {
        if (board.playerToMoveNext() == botPlayer) {
            const ret = board.findBestMoveMinimax();
            try stdout.print("\nBot move: \x1b[96m{c}{c}\x1b[0m\n", .{ ret.move / 3 + 'A', ret.move % 3 + '1' });
            try board.move(ret.move);
        } else {
            try stdout.print("\nPlayer to move: \x1b[31m{c}\x1b[0m\n", .{@intFromEnum(board.playerToMoveNext())});

            try board.printBoard();

            try stdout.print("Enter your move:\n» \x1b[96m", .{});

            var inBuffer = [_]u8{0} ** 1024;

            while (true) : (try stdout.print("Invalid move, try again:\n» \x1b[96m", .{})) {
                _ = stdin.readUntilDelimiterOrEof(inBuffer[0..], '\n') catch continue;
                try stdout.print("\x1b[0m", .{});

                if (inBuffer[0] == 'q' or inBuffer[0] == 0) {
                    try stdout.print("\n", .{});
                    return;
                }

                inBuffer[0] = std.ascii.toUpper(inBuffer[0]);

                if (!('A' <= inBuffer[0] and inBuffer[0] <= 'C' and
                    '1' <= inBuffer[1] and inBuffer[1] <= '3'))
                {
                    continue;
                }

                const fieldIndex = (inBuffer[0] - 'A') * 3 + (inBuffer[1] - '1');
                board.move(fieldIndex) catch continue;
                break;
            }
        }
    }

    try board.printBoard();
    const winner = board.checkForWinner();

    if (winner == Board.Player.NoPlayer) {
        try stdout.print("\x1b[31mDraw\x1b[0m\n", .{});
    } else {
        try stdout.print("Winner: \x1b[31m{c}\x1b[0m\n", .{@intFromEnum(winner)});
    }
}
