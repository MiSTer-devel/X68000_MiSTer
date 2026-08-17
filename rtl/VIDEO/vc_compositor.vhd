library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vc_compositor_normal is
    port (
        pri_sp      : in  std_logic_vector(1 downto 0);
        pri_tx      : in  std_logic_vector(1 downto 0);
        pri_gr      : in  std_logic_vector(1 downto 0);
        spren       : in  std_logic;
        txten       : in  std_logic;
        grpen       : in  std_logic;
        exon        : in  std_logic;
        hp          : in  std_logic;
        plsb        : in  std_logic;
        gg          : in  std_logic;
        gt          : in  std_logic;
        ah          : in  std_logic;
        sp_pal      : in  std_logic_vector(7 downto 0);
        tx_pal      : in  std_logic_vector(3 downto 0);
        sp_color    : in  std_logic_vector(15 downto 0);
        sp_color0   : in  std_logic_vector(15 downto 0);
        tx_color    : in  std_logic_vector(15 downto 0);
        tx_color0   : in  std_logic_vector(15 downto 0);
        gr_color    : in  std_logic_vector(15 downto 0);
        gr_code1    : in  std_logic_vector(15 downto 0);
        gr_selected_rank2 : in std_logic;
        gr_first_trigger  : in std_logic;
        gr_even     : in  std_logic_vector(15 downto 0);
        gr_odd2     : in  std_logic_vector(15 downto 0);
        out_color   : out std_logic_vector(15 downto 0);
        out_source  : out std_logic_vector(1 downto 0);
        out_valid   : out std_logic
    );
end entity;

architecture rtl of vc_compositor_normal is
    constant SRC_NONE : std_logic_vector(1 downto 0) := "00";
    constant SRC_GR   : std_logic_vector(1 downto 0) := "01";
    constant SRC_SP   : std_logic_vector(1 downto 0) := "10";
    constant SRC_TX   : std_logic_vector(1 downto 0) := "11";

    function mix_x (
        front : std_logic_vector(15 downto 0);
        rear  : std_logic_vector(15 downto 0)
    ) return std_logic_vector is
        variable sum_g : unsigned(5 downto 0);
        variable sum_r : unsigned(5 downto 0);
        variable sum_b : unsigned(5 downto 0);
        variable mixed : std_logic_vector(15 downto 0);
    begin
        sum_g := unsigned('0' & front(15 downto 11)) +
                 unsigned('0' & rear(15 downto 11));
        sum_r := unsigned('0' & front(10 downto 6)) +
                 unsigned('0' & rear(10 downto 6));
        sum_b := unsigned('0' & front(5 downto 1)) +
                 unsigned('0' & rear(5 downto 1));
        mixed(15 downto 11) := std_logic_vector(sum_g(5 downto 1));
        mixed(10 downto 6)  := std_logic_vector(sum_r(5 downto 1));
        mixed(5 downto 1)   := std_logic_vector(sum_b(5 downto 1));
        mixed(0)             := rear(0);
        return mixed;
    end function;
begin
    process (
        pri_sp, pri_tx, pri_gr, spren, txten, grpen,
        exon, hp, plsb, gg, gt, ah,
        sp_pal, tx_pal, sp_color, sp_color0,
        tx_color, tx_color0, gr_color,
        gr_code1, gr_selected_rank2, gr_first_trigger, gr_even, gr_odd2
    )
        variable sp_pal_eff       : unsigned(7 downto 0);
        variable tx_pal_eff       : unsigned(3 downto 0);
        variable st_front         : std_logic_vector(1 downto 0);
        variable rep_source       : std_logic_vector(1 downto 0);
        variable rep_color        : std_logic_vector(15 downto 0);
        variable first_source     : std_logic_vector(1 downto 0);
        variable second_source    : std_logic_vector(1 downto 0);
        variable first_color      : std_logic_vector(15 downto 0);
        variable second_color     : std_logic_vector(15 downto 0);
        variable st_present       : boolean;
        variable gr_present       : boolean;
        variable rep_before_graph : boolean;
        variable normal_source    : std_logic_vector(1 downto 0);
        variable normal_color     : std_logic_vector(15 downto 0);
        variable normal_valid     : std_logic;
        variable result_source    : std_logic_vector(1 downto 0);
        variable result_color     : std_logic_vector(15 downto 0);
        variable result_valid     : std_logic;
        variable behind_color     : std_logic_vector(15 downto 0);
        variable candidate        : std_logic_vector(15 downto 0);
        variable graphic_mix      : std_logic_vector(15 downto 0);
        variable base_gr_color    : std_logic_vector(15 downto 0);
        variable trigger          : boolean;
        variable st_blocks_graph  : boolean;
        variable selected_rank2   : boolean;
    begin
        if spren = '1' then
            sp_pal_eff := unsigned(sp_pal);
        else
            sp_pal_eff := (others => '0');
        end if;
        if txten = '1' then
            tx_pal_eff := unsigned(tx_pal);
        else
            tx_pal_eff := (others => '0');
        end if;

        st_present := spren = '1' or txten = '1';
        gr_present := grpen = '1';
        rep_before_graph := false;
        selected_rank2 := gr_selected_rank2 = '1';

        base_gr_color := gr_color;
        if exon = '1' and plsb = '1' and
           (hp = '0' or gg = '1' or gt = '1') then
            base_gr_color := gr_even;
        end if;

        if unsigned(pri_sp) < unsigned(pri_tx) then
            st_front := SRC_SP;
        else
            st_front := SRC_TX;
        end if;

        if st_front = SRC_SP then
            if sp_pal_eff(3 downto 0) /= 0 or
               (sp_pal_eff /= 0 and tx_pal_eff = 0) then
                rep_source := SRC_SP;
            else
                rep_source := SRC_TX;
            end if;
        else
            if tx_pal_eff /= 0 then
                rep_source := SRC_TX;
            else
                rep_source := SRC_SP;
            end if;
        end if;

        if rep_source = SRC_SP then
            if spren = '1' then
                rep_color := sp_color;
            else
                rep_color := sp_color0;
            end if;
        else
            if txten = '1' then
                rep_color := tx_color;
            else
                rep_color := tx_color0;
            end if;
        end if;

        if spren = '0' and txten = '1' and tx_pal_eff = 0 then
            rep_source := SRC_TX;
            rep_color  := (others => '0');
            st_present := false;
        end if;

        if pri_gr = "11" and gr_present then
            rep_source := SRC_TX;
            rep_color  := tx_color0;
            st_present := true;
        end if;

        normal_source := SRC_NONE;
        normal_color  := (others => '0');
        normal_valid  := '0';

        if pri_gr = "11" then
            if gr_present then
                if base_gr_color /= x"0000" then
                    normal_color  := base_gr_color;
                    normal_source := SRC_GR;
                else
                    normal_color  := tx_color0;
                    normal_source := SRC_TX;
                end if;
                normal_valid := '1';
            end if;
        elsif not st_present and not gr_present then
            null;
        elsif not st_present then
            if base_gr_color /= x"0000" then
                normal_color  := base_gr_color;
                normal_source := SRC_GR;
                normal_valid  := '1';
            end if;
        elsif not gr_present then
            if rep_color /= x"0000" then
                normal_color  := rep_color;
                normal_source := rep_source;
                normal_valid  := '1';
            end if;
        else
            rep_before_graph :=
                pri_gr = "10" or
                (pri_gr = "01" and rep_source = st_front);

            if rep_before_graph then
                first_source  := rep_source;
                first_color   := rep_color;
                second_source := SRC_GR;
                second_color  := base_gr_color;
            else
                first_source  := SRC_GR;
                first_color   := base_gr_color;
                second_source := rep_source;
                second_color  := rep_color;
            end if;

            if first_color /= x"0000" then
                normal_color  := first_color;
                normal_source := first_source;
                normal_valid  := '1';
            elsif second_color /= x"0000" then
                normal_color  := second_color;
                normal_source := second_source;
                normal_valid  := '1';
            end if;
        end if;

        result_color  := normal_color;
        result_source := normal_source;
        result_valid  := normal_valid;

        if ah = '1' and gr_present then
            result_color  := mix_x(gr_color, tx_color0);
            result_source := SRC_GR;
            result_valid  := '1';
        elsif exon = '1' and gr_present then
            if hp = '0' then
                if plsb = '0' then
                    trigger := gr_code1 /= x"0000" and gr_even(0) = '1';
                    if trigger then
                        result_color  := gr_color;
                        result_source := SRC_GR;
                        result_valid  := '1';
                    end if;
                else
                    trigger := gr_first_trigger = '1';
                    if trigger then
                        result_color  := gr_even;
                        result_source := SRC_GR;
                        result_valid  := '1';
                    end if;
                end if;

            elsif gg = '1' or gt = '1' then
                st_blocks_graph := st_present and rep_before_graph and
                                   rep_color /= x"0000";
                if st_blocks_graph then
                    result_color  := rep_color;
                    result_source := rep_source;
                    result_valid  := '1';
                else
                    if st_present then
                        behind_color := rep_color;
                    else
                        behind_color := (others => '0');
                    end if;

                    if plsb = '0' then
                        trigger := gr_even(0) = '1';
                    else
                        trigger := gr_first_trigger = '1';
                    end if;

                    if gg = '0' then
                        if trigger then
                            if plsb = '0' then
                                candidate := mix_x(gr_color, behind_color);
                            else
                                candidate := mix_x(gr_even, behind_color);
                            end if;
                            result_color  := candidate;
                            result_source := SRC_GR;
                            result_valid  := '1';
                        else
                            candidate := base_gr_color;
                            if candidate /= x"0000" then
                                result_color  := candidate;
                                result_source := SRC_GR;
                                result_valid  := '1';
                            elsif behind_color /= x"0000" then
                                result_color  := behind_color;
                                result_source := rep_source;
                                result_valid  := '1';
                            else
                                result_color  := (others => '0');
                                result_source := SRC_NONE;
                                result_valid  := '0';
                            end if;
                        end if;
                    else
                        if trigger then
                            graphic_mix := mix_x(gr_even, gr_odd2);
                            if gt = '1' then
                                candidate := mix_x(graphic_mix, behind_color);
                                result_color  := candidate;
                                result_source := SRC_GR;
                                result_valid  := '1';
                            elsif plsb = '1' and graphic_mix = x"0000" and behind_color /= x"0000" then
                                result_color  := behind_color;
                                result_source := rep_source;
                                result_valid  := '1';
                            else
                                result_color  := graphic_mix;
                                result_source := SRC_GR;
                                result_valid  := '1';
                            end if;
                        else
                            if plsb = '0' and gr_code1(0) = '1' and not selected_rank2 then
                                candidate := gr_odd2;
                            else
                                candidate := base_gr_color;
                            end if;
                            if candidate /= x"0000" then
                                result_color  := candidate;
                                result_source := SRC_GR;
                                result_valid  := '1';
                            elsif behind_color /= x"0000" then
                                result_color  := behind_color;
                                result_source := rep_source;
                                result_valid  := '1';
                            else
                                result_color  := (others => '0');
                                result_source := SRC_NONE;
                                result_valid  := '0';
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;

        out_color  <= result_color;
        out_source <= result_source;
        out_valid  <= result_valid;
    end process;
end architecture;
