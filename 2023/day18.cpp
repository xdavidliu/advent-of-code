#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <exception>
#include <algorithm>
#include <string_view>
#include <queue>
#include <set>

constexpr char filepath[] = "/home/employee/Documents/temp/example.txt";

struct Dig {
    char dir;
    long steps;
};

void my_assert(const bool cond, const std::string_view msg) {
    if (!cond) {
        std::cout << msg << '\n';
        throw std::exception();
    }
}

Dig dig_from(const std::string& rgb) {
    // 2 because of (#
    const auto steps = std::stoi(rgb.substr(2, 5), nullptr, 16);
    const auto second_to_last = *(rgb.crbegin() + 1);
    switch (second_to_last) {
        case '0':return {'R', steps};
        case '1':return {'D', steps};
        case '2':return {'L', steps};
        case '3':return {'U', steps};
        default: throw std::exception();
    }
}

std::pair<std::vector<Dig>, std::vector<Dig>> read_digs() {
    if (auto fs = std::fstream(filepath)) {
        std::vector<Dig> out1, out2;
        long steps = 0;
        char dir;
        std::string rgb;
        while (fs >> dir) {
            fs >> steps >> rgb;
            out1.push_back({dir, steps});
            out2.push_back(dig_from(rgb));
        }
        return {out1, out2};
    } else {
        throw std::exception();
    }
}

// x, top, bottom, is_up
// top means low number of row, bottom means high number
// i.e. in a grid
using Vertical = std::tuple<long, long, long, bool>;

auto get_x(const Vertical &vert) {
    return std::get<0>(vert);
}

auto get_top(const Vertical &vert) {
    return std::get<1>(vert);
}

auto get_bottom(const Vertical &vert) {
    return std::get<2>(vert);
}

auto is_up(const Vertical &vert) {
    return std::get<3>(vert);
}

bool less_top(const Vertical &a, const Vertical &b) {
    return get_top(a) < get_top(b);
}

class GreaterBottom {
public:
    bool operator() (const Vertical &a, const Vertical &b) {
        return get_bottom(a) > get_bottom(b);
    }
};

auto verticals_by_top(const std::vector<Dig> &digs) {
    std::vector<Vertical> out;
    long x = 0, row = 0;
    for (const auto &dig : digs) {
        switch (dig.dir) {
            case 'L': {
                x -= dig.steps;
                break;
            }
            case 'R': {
                x += dig.steps;
                break;
            }
            case 'U': {
                const auto old_row = row;
                row -= dig.steps;
                out.emplace_back(x, row, old_row, true);
                break;
            }
            case 'D': {
                const auto old_row = row;
                row += dig.steps;
                out.emplace_back(x, old_row, row, false);
            }
        }
    }
    std::sort(out.begin(), out.end(), less_top);
    return out;
}

auto recompute_cross_section(const std::set<Vertical> &heap_set) {
    long cross_section = 0;
    // expect heap size to be even now
    // expect from left to right all unique x
    // expect turn on off on off in that order, don't even care about clockwise
    bool entering = true;
    long last_x = 0; // unused on first iteration
    for (const auto &vert : heap_set) {
        const auto this_x = get_x(vert);
        if (!entering) {
            cross_section += this_x - last_x + 1;
        }
        entering = !entering;
        last_x = this_x;
    }
    return cross_section;
}

auto compute_intersecting_cross_section(const std::set<Vertical> &heap_set, const long row) {
    long cross_section = 0;
    return cross_section;
}

long solve(const std::vector<Vertical> &verts) {
    // min_heap, peek has smallest bottom
    std::priority_queue<Vertical, std::vector<Vertical>, GreaterBottom> heap;
    // keep matched so can quickly iterate through by x
    std::set<Vertical> heap_set;
    auto iter = verts.cbegin();
    // top has only starting
    auto last_row = get_top(*iter);  // last as in prev, not final
    while (last_row == get_top(*iter)) {
        heap_set.insert(*iter);
        heap.push(*iter);
        ++iter;
    }
    auto cross_section = recompute_cross_section(heap_set);
    long area = cross_section;  // first row trivially included
    while (iter != verts.cend()) {
        my_assert(!heap.empty(), "heap empty");
        // every beginning of vert in iter has an end of a vert in heap
        const auto next = get_top(*iter);
        area += cross_section * (next - last_row - 1);
        last_row = next;
        // put new ones in heap first so we can calculate cross section of just
        // this row
        while (iter != verts.cend() && next == get_top(*iter)) {
            heap_set.insert(*iter);
            heap.push(*iter);
            ++iter;
        }
        area += compute_intersecting_cross_section(heap_set, next);
        // no need to check if heap empty; cannot empty until while loop terminates
        while (next == get_bottom(heap.top())) {
            heap_set.erase(heap.top());
            heap.pop();
        }
        // exiting verticals don't participate in next cross-section
        cross_section = recompute_cross_section(heap_set);
    }
    // bottom row still contained
    cross_section = recompute_cross_section(heap_set);
    const auto next = get_bottom(heap.top());
    return area + cross_section * (next - last_row);
}

int main() {
    const auto [digs1, digs2] = read_digs();
    const auto verts1 = verticals_by_top(digs1);
    const auto verts2 = verticals_by_top(digs2);
    const auto part1 = solve(verts1);
    std::cout << "part 1 = " << part1 << '\n';  // 49897
//    std::cout << "part 2 = " << solve(verts2) << '\n';
}