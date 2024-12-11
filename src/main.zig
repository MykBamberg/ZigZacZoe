const std = @import("std");

const stdin = std.io.getStdIn().reader();    
const stdout = std.io.getStdOut().writer();

const Board = struct 
{
    BoardState: [9]Player = [_]Player{Player.NoPlayer} ** 9,
    
    const Player = enum(u8) 
    {
        NoPlayer = ' ',
        PlayerX  = 'X',
        PlayerO  = 'O',
    };
    
    fn printBoard(self: Board) !void
    {
        var boardString: [56]u8 =
        \\
        \\ #-1-2-3-#
        \\A| R R R |
        \\B| R R R |
        \\C| R R R |
        \\ #-------#
        \\
        .*; // R will be replaced
        
        var fieldIndex: u8 = 0;
        for(boardString, 0..) |char, charIndex|
        {
            if(char == 'R')
            {
                boardString[charIndex] = @intFromEnum(self.BoardState[fieldIndex]);
                fieldIndex+=1;
            }
        }
        
        try stdout.print("{s}\n", .{boardString});
    }
    
    fn checkForWinner(self: Board) Player
    {
        const state = self.BoardState;
        
        // Board layout:
        // 0 1 2
        // 3 4 5
        // 6 7 8
        
        //Diagonals
        if (state[4] != Player.NoPlayer and (
                (state[0] == state[4] and state[4] == state[8]) or
                (state[2] == state[4] and state[4] == state[6])))
        {
            return state[4];
        }
        
        for (0..3) |i|
        {
            if(state[i * 3 + 0] == state[i * 3 + 1] and 
               state[i * 3 + 1] == state[i * 3 + 2] and
               state[i * 3 + 1] != Player.NoPlayer) //Rows
            {
                return state[i * 3 + 1];
            }
            
            if(state[i + 0] == state[i + 3] and 
               state[i + 3] == state[i + 6] and 
               state[i + 3] != Player.NoPlayer) //Columns
            {
                return state[i + 6];
            }
        }
        
        return Player.NoPlayer;
    }
    
    fn checkForDraw(self: Board) bool
    {
        if (checkForWinner(self) != Player.NoPlayer) return false;
        for (self.BoardState) |field|
        {
            if (field == Player.NoPlayer) return false;
        }
        
        return true;
    }
    
    fn playerToMoveNext(self: Board) Player
    {
        var xPieces: u8 = 0;
        var oPieces: u8 = 0;
        
        for(self.BoardState) |piece|
        {
            if (piece == Player.PlayerX) xPieces += 1;
            if (piece == Player.PlayerO) oPieces += 1;
        }
        
        return if (xPieces == oPieces) Player.PlayerX else Player.PlayerO;
    }
    
    const MoveError = error{Occupied, GameOver};
    
    fn move(self: *Board, fieldIndex: u8) MoveError!void
    {
        if(checkForWinner(self.*) != Player.NoPlayer) return MoveError.GameOver;
        if(self.BoardState[fieldIndex] != Player.NoPlayer) return MoveError.Occupied;
        
        self.BoardState[fieldIndex] = playerToMoveNext(self.*);
    }
    
    const MinimaxReturn = struct{score: i16, move: u8};
    
    fn findBestMoveMinimax(board: Board) MinimaxReturn //standard Minimax
    {
        if (board.checkForDraw()) return MinimaxReturn{.score = 0, .move = 0};
        const currentWinner = board.checkForWinner();
        
        if (currentWinner != Player.NoPlayer)
            return switch (currentWinner) 
            {
                Player.PlayerX => MinimaxReturn{.score = @as(i16,  1024), .move = 0},
                Player.PlayerO => MinimaxReturn{.score = @as(i16, -1024), .move = 0},
                Player.NoPlayer => unreachable
            };
        
        //game not over
        
        const currentPlayer = board.playerToMoveNext();
        var returnValues: [9]?MinimaxReturn = [_]?MinimaxReturn{null} ** 9;
        var boardCopy = board;
        
        for (0..9) |i| //loop through every move, discard impossible moves
        {
            if (board.BoardState[i] == Player.NoPlayer)
            {
                boardCopy.BoardState[i] = currentPlayer;
                returnValues[i] = findBestMoveMinimax(boardCopy);
                boardCopy.BoardState[i] = Player.NoPlayer;
            }
        }
        
        const evalMultiplier: i16 = if(currentPlayer == Player.PlayerX) 1 else -1;
        
        var bestScore: i16 = -1024;
        var bestReturnIndex: u8 = undefined;
        
        for(returnValues, 0..) |possibleNullValue, i| //loop through every possible move, select most favorable for current player
            if (possibleNullValue) |value|
            {
                if(value.score * evalMultiplier > bestScore)
                {
                    bestScore = value.score * evalMultiplier;
                    bestReturnIndex = @intCast(i);
                }
            };
        
        return MinimaxReturn
        {
            .score = returnValues[bestReturnIndex].?.score >> 1, //reduce score to select fastest winning move
            .move = bestReturnIndex
        };
    }
};

pub fn main() !void 
{
    var board: Board = Board{};
    
    while (board.checkForWinner() == Board.Player.NoPlayer and !board.checkForDraw()) //Main Game 
    {
        try board.printBoard();
        
        try stdout.print("Player to move: {c}\n", .{@intFromEnum(board.playerToMoveNext())});
        
        if (board.playerToMoveNext() == Board.Player.PlayerO) //Automate player O
        //if (board.playerToMoveNext() == Board.Player.PlayerX) //Automate player X
        //if (true) //Bot vs. Bot
        //if (false) //Human vs. Human
        {
            const ret = board.findBestMoveMinimax();
            try board.move(ret.move);
            continue;
        }
        
        try stdout.print("Enter your move:\n", .{});
        
        var inBuffer = [_]u8{0} ** 1024;
        
        while(true) : (try stdout.print("Try again:\n", .{})) //Get user input retry if input malformed
        {
            _ = stdin.readUntilDelimiterOrEof(inBuffer[0..], '\n') catch continue;
            if (!('A' <= inBuffer[0] and inBuffer[0] <= 'C' and
                  '1' <= inBuffer[1] and inBuffer[1] <= '3'))
            {
                continue;
            }
            
            const fieldIndex = (inBuffer[0] - 'A') * 3 + 
                               (inBuffer[1] - '1');
            
            board.move(fieldIndex) catch continue;
            
            break; //Input in correct format
        }
    }
    
    try board.printBoard();
    const winner = board.checkForWinner();
    
    if (winner == Board.Player.NoPlayer)
    {
        try stdout.print("Draw\n", .{});
    }
    else
    {
        try stdout.print("Winner: {c}\n", .{@intFromEnum(winner)});
    }
}
